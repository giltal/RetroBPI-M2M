// SPDX-License-Identifier: GPL-2.0
/*
 * Waveshare 5inch DSI LCD (B) - 800x480, 1-lane MIPI-DSI
 *
 * The panel is a Raspberry Pi 7" touchscreen clone: a Toshiba TC358762
 * DSI->DPI bridge driven over DSI, plus an ATTINY-compatible MCU on I2C 0x45
 * that owns power, backlight and the reset lines. Verified on hardware:
 *
 *   i2cget 0x45 0x80 -> 0xc3   (REG_ID "ver 2" - genuine RPi ATTINY map)
 *   i2cget 0x45 0x97 -> 0x8b   (not 0x46/0x65, so not the newer Waveshare map)
 *   touch responds at 0x38 (FT5x06)
 *
 * So the MCU side is handled by the stock mainline rpi-panel-attiny-regulator,
 * referenced from DT as power-supply / backlight / reset-gpios. This driver
 * only does what that cannot: the TC358762 register writes over DSI.
 *
 * Why not just use mainline's panel-raspberrypi-touchscreen or tc358762?
 * Neither attaches on this SoC. sun6i_dsi_attach() does:
 *
 *	panel = of_drm_find_panel(device->dev.of_node);
 *
 * and nothing else - no drm_of_find_panel_or_bridge, no bridge chain. So the
 * panel must be a drm_panel registered against the DSI *child* node.
 * panel-raspberrypi-touchscreen registers its panel against the i2c node while
 * its DSI device gets a port node, so the lookup misses; tc358762 registers a
 * drm_bridge, which is not a drm_panel at all.
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>

#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

/* TC358762 registers, names per mainline drivers/gpu/drm/bridge/tc358762.c */
#define PPI_STARTPPI		0x0104
#define PPI_LPTXTIMECNT		0x0114
#define PPI_D0S_ATMR		0x0144
#define PPI_D1S_ATMR		0x0148
#define PPI_D0S_CLRSIPOCOUNT	0x0164
#define PPI_D1S_CLRSIPOCOUNT	0x0168
#define PPI_START_FUNCTION	1

#define DSI_STARTDSI		0x0204
#define DSI_LANEENABLE		0x0210
#define DSI_RX_START		1

#define LCDCTRL			0x0420
#define LCDCTRL_VTGEN		BIT(4)
#define LCDCTRL_UNK6		BIT(6)
#define LCDCTRL_RGB888		BIT(8)
#define LCDCTRL_HSPOL		BIT(17)
#define LCDCTRL_DEPOL		BIT(18)
#define LCDCTRL_VSPOL		BIT(19)
#define LCDCTRL_VSDELAY(v)	(((v) & 0xfff) << 20)

#define SPICMR			0x0450
#define SYSCTRL			0x0464

/*
 * DPI output timing. Mainline's tc358762 driver never writes these, but we set
 * LCDCTRL_VTGEN ("use chip clock for timing"), which makes them authoritative.
 *
 * Field layout is not documented for the '762, but its video-path block is the
 * '764's at a different base - mainline tc358764.c has VP_CTRL at 0x0450 with
 * HTIM1/HTIM2/VTIM1/VTIM2/VFUEN at +4/+8/+c/+10/+14, and the '762 has LCDCTRL
 * at 0x0420 with the vendor writing the same five offsets. Confirmed by
 * arithmetic: computing VP_VTIM2 from ws_800_480 gives 0x000701e0, exactly the
 * vendor's constant.
 *
 * Hardcoding the rest of the vendor's constants was a mistake - they encode a
 * different timing (hfp 105 vs our 131, and vbp/vsync swapped), which showed up
 * on the panel as an image offset by ~1/3 screen that wrapped at the right
 * edge. Derive them from the mode instead.
 */
#define VP_HTIM1		0x0424	/* HBP[24:16], HSYNC[8:0]  */
#define VP_HTIM2		0x0428	/* HFP[24:16], HACT[10:0]  */
#define VP_VTIM1		0x042c	/* VBP[23:16], VSYNC[7:0]  */
#define VP_VTIM2		0x0430	/* VFP[23:16], VACT[10:0]  */
#define VP_VFUEN		0x0434	/* latch the timing above  */
#define VFUEN_EN		1

#define LPX_PERIOD		3

#define LANEENABLE_CLEN		BIT(0)
#define LANEENABLE_L0EN		BIT(1)

struct ws5b {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	struct gpio_desc *reset_gpio;
	struct regulator *supply;
};

/*
 * The panel's own timing, recovered from the Rockchip vendor blob's TC358762
 * VP_HTIM/VP_VTIM constants:
 *
 *   0x001a0014 -> hbp=26 hsync=20      0x00690320 -> hfp=105 hact=800
 *   0x00150002 -> vbp=21 vsync=2       0x000701e0 -> vfp=7   vact=480
 *
 * giving 951 x 510, 60 Hz at 29.101 MHz.
 *
 * Note this is NOT the ws_800_480 node from the Lyra's device tree
 * (978 x 511 @ 30 MHz, hfp 131 / hsync 45 / hbp 2). That is what the Rockchip
 * SoC pushed over DSI; the bridge was still told the panel's real timing by
 * the blob. Sending ws_800_480 here left a 27 px/line mismatch between the DSI
 * input and the DPI output, which showed on the panel as an image offset by
 * about a third of the screen that wrapped at the right edge.
 *
 * Since VP_HTIM/VP_VTIM below are derived from this mode, DSI input and DPI
 * output now describe the same timing, and the derived values come out
 * bit-identical to the vendor's constants.
 */
static const struct drm_display_mode ws5b_mode = {
	.clock		= 29101,
	.hdisplay	= 800,
	.hsync_start	= 800 + 105,
	.hsync_end	= 800 + 105 + 20,
	.htotal		= 800 + 105 + 20 + 26,
	.vdisplay	= 480,
	.vsync_start	= 480 + 7,
	.vsync_end	= 480 + 7 + 2,
	.vtotal		= 480 + 7 + 2 + 21,
	.flags		= DRM_MODE_FLAG_NHSYNC | DRM_MODE_FLAG_NVSYNC,
	.width_mm	= 108,
	.height_mm	= 65,
	.type		= DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED,
};

static inline struct ws5b *panel_to_ws5b(struct drm_panel *panel)
{
	return container_of(panel, struct ws5b, panel);
}

/* TC358762 takes 16-bit reg + 32-bit value, both little endian, as a
 * 6-byte generic long write.
 */
static void ws5b_write(struct mipi_dsi_multi_context *ctx, u16 addr, u32 val)
{
	u8 d[6];

	d[0] = addr;
	d[1] = addr >> 8;
	d[2] = val;
	d[3] = val >> 8;
	d[4] = val >> 16;
	d[5] = val >> 24;

	mipi_dsi_generic_write_multi(ctx, d, sizeof(d));
}

static int ws5b_prepare(struct drm_panel *panel)
{
	struct ws5b *ctx = panel_to_ws5b(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };
	u32 lcdctrl;
	int ret;

	/*
	 * On this panel "power" and "reset" are both the 0x45 MCU: the
	 * regulator is REG_POWERON (0x85), and reset-gpios comes from the same
	 * chip's gpio-controller. The MCU needs ~800 ms after power-on before
	 * the bridge answers - that delay lives in the attiny driver, but give
	 * it margin here too.
	 */
	if (ctx->supply) {
		ret = regulator_enable(ctx->supply);
		if (ret)
			return ret;
		msleep(20);
	}

	if (ctx->reset_gpio) {
		gpiod_set_value_cansleep(ctx->reset_gpio, 1);
		msleep(20);
		gpiod_set_value_cansleep(ctx->reset_gpio, 0);
		msleep(60);
	}

	ws5b_write(&dsi_ctx, DSI_LANEENABLE, LANEENABLE_L0EN | LANEENABLE_CLEN);
	ws5b_write(&dsi_ctx, PPI_D0S_CLRSIPOCOUNT, 5);
	ws5b_write(&dsi_ctx, PPI_D1S_CLRSIPOCOUNT, 5);
	ws5b_write(&dsi_ctx, PPI_D0S_ATMR, 0);
	ws5b_write(&dsi_ctx, PPI_D1S_ATMR, 0);
	ws5b_write(&dsi_ctx, PPI_LPTXTIMECNT, LPX_PERIOD);
	ws5b_write(&dsi_ctx, SPICMR, 0x00);

	lcdctrl = LCDCTRL_VSDELAY(1) | LCDCTRL_RGB888 | LCDCTRL_UNK6 |
		  LCDCTRL_VTGEN;

	/*
	 * Polarity. Both syncs are active low in ws_800_480, so this ends up
	 * as 0x001a0150. Note the Rockchip vendor blob for this same panel
	 * wrote 0x00100152 - no polarity bits at all, plus an undocumented
	 * BIT(1) - and worked, because Rockchip applies polarity further up the
	 * pipe. If the image is shifted, rolling or torn, this is the first
	 * thing to try changing.
	 */
	if (ws5b_mode.flags & DRM_MODE_FLAG_NHSYNC)
		lcdctrl |= LCDCTRL_HSPOL;
	if (ws5b_mode.flags & DRM_MODE_FLAG_NVSYNC)
		lcdctrl |= LCDCTRL_VSPOL;

	ws5b_write(&dsi_ctx, LCDCTRL, lcdctrl);

	/*
	 * DPI output timing, derived from the mode rather than hardcoded.
	 * LCDCTRL_VTGEN above tells the bridge to generate its own timing from
	 * these, so they are authoritative - get them wrong and the image is
	 * offset and wraps.
	 */
	{
		const struct drm_display_mode *m = &ws5b_mode;
		u32 hbp   = m->htotal      - m->hsync_end;
		u32 hsync = m->hsync_end   - m->hsync_start;
		u32 hfp   = m->hsync_start - m->hdisplay;
		u32 vbp   = m->vtotal      - m->vsync_end;
		u32 vsync = m->vsync_end   - m->vsync_start;
		u32 vfp   = m->vsync_start - m->vdisplay;

		ws5b_write(&dsi_ctx, VP_HTIM1, (hbp   << 16) | hsync);
		ws5b_write(&dsi_ctx, VP_HTIM2, (hfp   << 16) | m->hdisplay);
		ws5b_write(&dsi_ctx, VP_VTIM1, (vbp   << 16) | vsync);
		ws5b_write(&dsi_ctx, VP_VTIM2, (vfp   << 16) | m->vdisplay);
		ws5b_write(&dsi_ctx, VP_VFUEN, VFUEN_EN);
	}

	ws5b_write(&dsi_ctx, SYSCTRL, 0x040f);
	mipi_dsi_msleep(&dsi_ctx, 100);

	ws5b_write(&dsi_ctx, PPI_STARTPPI, PPI_START_FUNCTION);
	ws5b_write(&dsi_ctx, DSI_STARTDSI, DSI_RX_START);
	mipi_dsi_msleep(&dsi_ctx, 100);

	if (dsi_ctx.accum_err) {
		if (ctx->reset_gpio)
			gpiod_set_value_cansleep(ctx->reset_gpio, 1);
		if (ctx->supply)
			regulator_disable(ctx->supply);
	}

	return dsi_ctx.accum_err;
}

static int ws5b_unprepare(struct drm_panel *panel)
{
	struct ws5b *ctx = panel_to_ws5b(panel);

	if (ctx->reset_gpio)
		gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	if (ctx->supply)
		regulator_disable(ctx->supply);

	return 0;
}

static int ws5b_get_modes(struct drm_panel *panel,
			  struct drm_connector *connector)
{
	struct drm_display_mode *mode;

	mode = drm_mode_duplicate(connector->dev, &ws5b_mode);
	if (!mode)
		return -ENOMEM;

	drm_mode_set_name(mode);
	drm_mode_probed_add(connector, mode);

	connector->display_info.width_mm = ws5b_mode.width_mm;
	connector->display_info.height_mm = ws5b_mode.height_mm;

	return 1;
}

static const struct drm_panel_funcs ws5b_funcs = {
	.prepare	= ws5b_prepare,
	.unprepare	= ws5b_unprepare,
	.get_modes	= ws5b_get_modes,
};

static int ws5b_probe(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	struct ws5b *ctx;
	int ret;

	ctx = devm_drm_panel_alloc(dev, struct ws5b, panel, &ws5b_funcs,
				   DRM_MODE_CONNECTOR_DSI);
	if (IS_ERR(ctx))
		return PTR_ERR(ctx);

	ctx->reset_gpio = devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(ctx->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(ctx->reset_gpio),
				     "failed to get reset GPIO\n");

	ctx->supply = devm_regulator_get_optional(dev, "power");
	if (IS_ERR(ctx->supply)) {
		if (PTR_ERR(ctx->supply) != -ENODEV)
			return dev_err_probe(dev, PTR_ERR(ctx->supply),
					     "failed to get power supply\n");
		ctx->supply = NULL;
	}

	ret = drm_panel_of_backlight(&ctx->panel);
	if (ret)
		return dev_err_probe(dev, ret, "failed to get backlight\n");

	ctx->dsi = dsi;
	mipi_dsi_set_drvdata(dsi, ctx);

	/*
	 * 1 lane. The Lyra devlog is explicit that 2 lanes gives a white
	 * screen on this panel. Flags match mainline's tc358762 driver, which
	 * drives the same bridge.
	 */
	dsi->lanes = 1;
	dsi->format = MIPI_DSI_FMT_RGB888;
	dsi->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_SYNC_PULSE |
			  MIPI_DSI_MODE_LPM | MIPI_DSI_MODE_VIDEO_HSE;

	drm_panel_add(&ctx->panel);

	ret = mipi_dsi_attach(dsi);
	if (ret < 0) {
		drm_panel_remove(&ctx->panel);
		return dev_err_probe(dev, ret, "failed to attach to DSI host\n");
	}

	return 0;
}

static void ws5b_remove(struct mipi_dsi_device *dsi)
{
	struct ws5b *ctx = mipi_dsi_get_drvdata(dsi);

	mipi_dsi_detach(dsi);
	drm_panel_remove(&ctx->panel);
}

static const struct of_device_id ws5b_of_match[] = {
	{ .compatible = "waveshare,5inch-dsi-lcd-b" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, ws5b_of_match);

static struct mipi_dsi_driver ws5b_driver = {
	.probe = ws5b_probe,
	.remove = ws5b_remove,
	.driver = {
		.name = "panel-waveshare-dsi-b",
		.of_match_table = ws5b_of_match,
	},
};
module_mipi_dsi_driver(ws5b_driver);

MODULE_DESCRIPTION("Waveshare 5inch DSI LCD (B) panel driver");
MODULE_LICENSE("GPL");
