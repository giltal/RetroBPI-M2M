// SPDX-License-Identifier: GPL-2.0
/*
 * Fitipower EK79007 MIPI-DSI panel driver
 *
 * Targets the 7" 1024x600 panel shipped with the ESP32-P4-Function-EV-Board,
 * connected to a Banana Pi BPI-M2 Magic (Allwinner A33) through the
 * bpi24-dsi-flex adapter.
 *
 * Register sequence, timings and reset timing were taken from Espressif's
 * driver: esp-arduino-libs/ESP32_Display_Panel,
 * src/drivers/lcd/port/esp_lcd_ek79007.c
 *
 * Deliberately a plain drm_panel registered against the DSI child node:
 * sun6i_dsi_attach() only accepts of_drm_find_panel(device->dev.of_node),
 * so anything bridge-shaped or I2C-probed will not bind on this SoC.
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>

#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

struct ek79007 {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	struct gpio_desc *reset_gpio;
	struct regulator *supply;
};

/*
 * From the ESP32-P4 project:
 *   DPI clock 52 MHz, 1024x600
 *   HPW 10 / HBP 160 / HFP 160
 *   VPW  1 / VBP  23 / VFP  12
 * 52 MHz / (1354 * 636) = 60.4 Hz
 */
static const struct drm_display_mode ek79007_mode = {
	.clock		= 52000,
	.hdisplay	= 1024,
	.hsync_start	= 1024 + 160,
	.hsync_end	= 1024 + 160 + 10,
	.htotal		= 1024 + 160 + 10 + 160,
	.vdisplay	= 600,
	.vsync_start	= 600 + 12,
	.vsync_end	= 600 + 12 + 1,
	.vtotal		= 600 + 12 + 1 + 23,
	.width_mm	= 154,
	.height_mm	= 86,
	.type		= DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED,
};

static inline struct ek79007 *panel_to_ek79007(struct drm_panel *panel)
{
	return container_of(panel, struct ek79007, panel);
}

static int ek79007_prepare(struct drm_panel *panel)
{
	struct ek79007 *ctx = panel_to_ek79007(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };
	int ret;

	if (ctx->supply) {
		ret = regulator_enable(ctx->supply);
		if (ret)
			return ret;
		usleep_range(10000, 15000);
	}

	/* Vendor reset timing: assert 10 ms, release, settle 20 ms. */
	if (ctx->reset_gpio) {
		gpiod_set_value_cansleep(ctx->reset_gpio, 1);
		msleep(10);
		gpiod_set_value_cansleep(ctx->reset_gpio, 0);
		msleep(20);
	}

	/*
	 * The entire vendor init: seven register writes then sleep-out.
	 * Note there is no DISPON (0x29) — the reference driver does not
	 * send one, and this panel does not appear to need it.
	 */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x80, 0x8b);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x81, 0x78);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x82, 0x84);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x83, 0x88);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x84, 0xa8);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x85, 0xe3);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x86, 0x88);

	mipi_dsi_dcs_exit_sleep_mode_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 120);

	if (dsi_ctx.accum_err && ctx->supply)
		regulator_disable(ctx->supply);

	return dsi_ctx.accum_err;
}

static int ek79007_unprepare(struct drm_panel *panel)
{
	struct ek79007 *ctx = panel_to_ek79007(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	mipi_dsi_dcs_enter_sleep_mode_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 120);

	if (ctx->reset_gpio)
		gpiod_set_value_cansleep(ctx->reset_gpio, 1);

	if (ctx->supply)
		regulator_disable(ctx->supply);

	return 0;
}

static int ek79007_get_modes(struct drm_panel *panel,
			     struct drm_connector *connector)
{
	struct drm_display_mode *mode;

	mode = drm_mode_duplicate(connector->dev, &ek79007_mode);
	if (!mode)
		return -ENOMEM;

	drm_mode_set_name(mode);
	drm_mode_probed_add(connector, mode);

	connector->display_info.width_mm = ek79007_mode.width_mm;
	connector->display_info.height_mm = ek79007_mode.height_mm;

	return 1;
}

static const struct drm_panel_funcs ek79007_funcs = {
	.prepare	= ek79007_prepare,
	.unprepare	= ek79007_unprepare,
	.get_modes	= ek79007_get_modes,
};

static int ek79007_probe(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	struct ek79007 *ctx;
	int ret;

	ctx = devm_drm_panel_alloc(dev, struct ek79007, panel, &ek79007_funcs,
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

	/*
	 * Backlight on this hardware is the LED_CTRL line on the adapter
	 * board's J6 header, wired out to a BPI GPIO/PWM. Described in DT as
	 * a gpio- or pwm-backlight and picked up here, so the panel framework
	 * sequences it with prepare/enable.
	 */
	ret = drm_panel_of_backlight(&ctx->panel);
	if (ret)
		return dev_err_probe(dev, ret, "failed to get backlight\n");

	ctx->dsi = dsi;
	mipi_dsi_set_drvdata(dsi, ctx);

	dsi->lanes = 2;
	dsi->format = MIPI_DSI_FMT_RGB888;
	/*
	 * Espressif drives this through their DPI block and never exposes the
	 * DSI video-mode variant, so this is the one value that is a genuine
	 * guess. If the image tears or rolls, try adding
	 * MIPI_DSI_MODE_VIDEO_SYNC_PULSE, then MIPI_DSI_MODE_VIDEO_BURST.
	 */
	dsi->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_LPM;

	drm_panel_add(&ctx->panel);

	ret = mipi_dsi_attach(dsi);
	if (ret < 0) {
		drm_panel_remove(&ctx->panel);
		return dev_err_probe(dev, ret, "failed to attach to DSI host\n");
	}

	return 0;
}

static void ek79007_remove(struct mipi_dsi_device *dsi)
{
	struct ek79007 *ctx = mipi_dsi_get_drvdata(dsi);

	mipi_dsi_detach(dsi);
	drm_panel_remove(&ctx->panel);
}

static const struct of_device_id ek79007_of_match[] = {
	{ .compatible = "fitipower,ek79007" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, ek79007_of_match);

static struct mipi_dsi_driver ek79007_driver = {
	.probe = ek79007_probe,
	.remove = ek79007_remove,
	.driver = {
		.name = "panel-ek79007",
		.of_match_table = ek79007_of_match,
	},
};
module_mipi_dsi_driver(ek79007_driver);

MODULE_DESCRIPTION("Fitipower EK79007 MIPI-DSI panel driver");
MODULE_LICENSE("GPL");
