# Waveshare 5inch DSI LCD (B) — harvested reference

Everything below was pulled from the **working Lyra Zero W build**, which drives this exact panel.
Sources:
- `/home/giltal/Lyra-sdk/kernel-6.1/drivers/video/backlight/waveshare-backlight.c`
- `/home/giltal/Lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506b-luckfox-lyra-zero-w-sd.dts`

---

## 1. The 0x45 MCU — three register maps, auto-detected

The Luckfox/Waveshare driver (`waveshare-backlight.c`, compatible `waveshare,dsi-backlight`)
probes the MCU and picks one of three modes at runtime. **This is the key fact: the 0x45 device
is not always RPi-compatible.**

```
read 0x80  ->  0xde (v1) or 0xc3 (v2)  =>  RASPI_MODE
               anything else            =>  WS_RASPI_MODE
read 0x97  ->  0x46 or 0x65 (10inch1)   =>  WS_MODE   (overrides the above)
```

### RASPI_MODE — genuine RPi ATTINY map

| Op | Registers |
|---|---|
| Power-on | `0x85 = 0x00`, sleep 800 ms, `0x85 = 0x01`, sleep 800 ms, `0x81 = 0x04` |
| Brightness | `0x86 = brightness` (0–255, direct) |

This is **exactly** mainline `rpi-panel-attiny-regulator.c` (`REG_POWERON 0x85`, `REG_PWM 0x86`,
`REG_PORTA 0x81`). If our unit lands here, the stock mainline driver drops in unmodified.

### WS_RASPI_MODE — Waveshare clone map

| Op | Registers |
|---|---|
| Power-on | `0xc0 = 0x01`, `0xc2 = 0x01`, `0xac = 0x01` |
| Brightness | `0xab = 0xff - brightness`, then `0xaa = 0x01` (**inverted**) |
| Enable panel | `0xad = 0x01` (after backlight is up) |

Same registers as `panel-waveshare-dsi.c` in the RPi kernel tree. Mainline has **no** driver for
this map — it would need porting.

### WS_MODE — newest Waveshare map

```
REG_LCD 0x95   bits: VCC_EN BIT(4), BL_EN BIT(2), LCD_RST BIT(1), LCD_PWR BIT(0)
REG_PWM 0x96   brightness (direct)
REG_SIZE 0x97  panel id
```
Power-on: read `0x95`; if `LCD_PWR` clear → `0x95 = 0x11`, sleep 800 ms, `0x95 = 0x17`.
Brightness: set/clear `BL_EN` in `0x95`, then `0x96 = brightness`.

### ► ANSWERED on hardware (2026-08-17) — RASPI_MODE

Measured on the BPI-M2M with the probe DTB, panel on the Rev F flex:

```
i2cdetect -y 0   ->  0x38 and 0x45 present
i2cget -y 0 0x45 0x80  ->  0xc3     REG_ID, "ver 2"  => RASPI_MODE
i2cget -y 0 0x45 0x97  ->  0x8b     not 0x46/0x65    => NOT WS_MODE
i2cget -y 0 0x45 0x81  ->  0x04     REG_PORTA, matches the RPi init value
```

**The MCU speaks the genuine RPi ATTINY register map** — the best case. Consequences:

- mainline `rpi-panel-attiny-regulator` (`raspberrypi,7inch-touchscreen-panel-regulator`)
  works **unmodified**: it provides the regulator, the backlight (`REG_PWM` 0x86) and a
  gpio-controller for panel/touch reset.
- mainline `panel-raspberrypi-touchscreen` would accept this panel too — it validates `REG_ID`
  against exactly `0xde`/`0xc3`, and we read `0xc3`.
- the WS_RASPI / WS_MODE maps documented above are **not** needed for this unit.

Touch responds at **0x38** (FT5x06), matching the Lyra. Reading `0xa3`/`0xa8` returned `0x00`,
which is expected while the controller is still held in reset — on this panel family reset is
released by the 0x45 MCU, not by a GPIO.

**Still required despite all this:** neither stock driver *attaches* on sun6i.
`panel-raspberrypi-touchscreen` is I2C-probed (its panel is registered against the i2c node, while
the DSI device gets a port node — `of_drm_find_panel()` misses), and the `tc358762` path registers
a `drm_bridge`. `sun6i_dsi_attach()` accepts only a `drm_panel` on the DSI child node. So the plan
stands: a DSI-native panel driver doing the TC358762 init, with `rpi-panel-attiny-regulator`
supplying power, backlight and reset GPIOs from the 0x45 MCU.

---

## 2. TC358762 init sequence (from the Lyra DTS, proven on this panel)

Rockchip `panel-init-sequence` framing is `<dsi_type> <delay_ms> <payload_len> <payload…>`.
Type `0x29` = MIPI generic long write. Payload is `[reg_lo, reg_hi, val_b0..val_b3]` —
byte-for-byte what mainline's `tc358762_write()` emits.

Also set alongside it: `dsi,lanes = <1>`, `width-mm = <108>`, `height-mm = <65>`,
`native-mode = <&ws_800_480>`.

```
29 00 06 10 02 03 00 00 00     0x0210 DSI_LANEENABLE      = 0x00000003  (CLK + lane 0)
29 00 06 64 01 0c 00 00 00     0x0164 PPI_D0S_CLRSIPOCOUNT= 0x0000000c
29 00 06 68 01 0c 00 00 00     0x0168 PPI_D1S_CLRSIPOCOUNT= 0x0000000c
29 00 06 44 01 00 00 00 49     0x0144 PPI_D0S_ATMR        = 0x49000000  (?)
29 00 06 48 01 00 00 00 00     0x0148 PPI_D1S_ATMR        = 0x00000000
29 00 06 14 01 15 00 00 00     0x0114 PPI_LPTXTIMECNT     = 0x00000015
29 00 06 50 04 60 00 00 00     0x0450 SPICMR              = 0x00000060
29 00 06 20 04 52 01 10 00     0x0420 LCDCTRL             = 0x00100152
29 00 06 24 04 14 00 1a 00     0x0424                     = 0x001a0014
29 00 06 28 04 20 03 69 00     0x0428                     = 0x00690320
29 00 06 2c 04 02 00 15 00     0x042c                     = 0x00150002
29 00 06 30 04 e0 01 07 00     0x0430                     = 0x000701e0
29 00 06 34 04 01 00 00 00     0x0434                     = 0x00000001
29 00 06 64 04 0f 04 00 00     0x0464 SYSCTRL             = 0x0000040f
29 00 06 01 01 01 00 00 00     0x0101                     = 0x00000001  (?)
29 00 06 02 02 01 00 00 00     0x0202                     = 0x00000001  (?)
```

### Deltas vs mainline `tc358762_init()`

| Register | Lyra | mainline | note |
|---|---|---|---|
| `0x0210` LANEENABLE | 3 | 3 | same |
| `0x0164` / `0x0168` CLRSIPOCOUNT | 0x0c | 5 | timing |
| `0x0144` D0S_ATMR | **0x49000000** | 0 | suspicious — mainline writes 0, and D1S_ATMR here *is* 0 |
| `0x0148` D1S_ATMR | 0 | 0 | same |
| `0x0114` LPTXTIMECNT | 0x15 | 3 | timing |
| `0x0450` SPICMR | 0x60 | 0x00 | differs |
| `0x0420` LCDCTRL | 0x00100152 | 0x00100150 | Lyra also sets undocumented BIT(1) |
| `0x0424`–`0x0434` | programmed | **not written** | explicit DPI output timing — vendor extra |
| `0x0464` SYSCTRL | 0x040f | 0x040f | same |
| start | `0x0101` = 1, `0x0202` = 1 | `0x0104` PPI_STARTPPI = 1, `0x0204` DSI_STARTDSI = 1 | **addresses differ by 3** |

Two entries do not decode cleanly under the assumed framing: `0x0144 = 0x49000000` and the two
start writes at `0x0101` / `0x0202` rather than `0x0104` / `0x0204`. The Lyra display demonstrably
works with this blob, so either the vendor values are correct for this bridge revision or those
writes are inert and the bridge starts anyway. **Do not treat the decode of those three lines as
settled.**

### Recommendation

Start from **mainline `tc358762_init()`** — same chip, actively maintained, and its values are
what RPi ships for this panel family. Keep the Lyra blob as the fallback if the panel stays dark;
it is proven on this exact unit. The `0x0424`–`0x0434` DPI timing writes are the most likely thing
to have to add back, since mainline leaves the bridge to derive timing from the DSI stream.

---

## 3. Panel timings — `ws_800_480`, proven on this unit

From `rk3506-luckfox-lyra-ultra.dtsi:1026`:

```
clock-frequency = 30000000        hsync-len    = 45     vsync-len    = 22
hactive = 800                     hback-porch  = 2      vback-porch  = 2
vactive = 480                     hfront-porch = 131    vfront-porch = 7
vsync-active = 0   hsync-active = 0   de-active = 0   pixelclk-active = 0
```

As a `drm_display_mode`:

```c
static const struct drm_display_mode ws_5b_mode = {
	.clock       = 30000,            /* kHz */
	.hdisplay    = 800,
	.hsync_start = 800 + 131,        /*  931 */
	.hsync_end   = 800 + 131 + 45,   /*  976 */
	.htotal      = 800 + 131 + 45 + 2,   /* 978 */
	.vdisplay    = 480,
	.vsync_start = 480 + 7,          /*  487 */
	.vsync_end   = 480 + 7 + 22,     /*  509 */
	.vtotal      = 480 + 7 + 22 + 2, /*  511 */
	.flags       = DRM_MODE_FLAG_NHSYNC | DRM_MODE_FLAG_NVSYNC,
	.width_mm    = 108,
	.height_mm   = 65,
};
```

30 MHz / (978 × 511) = **60.03 Hz** — checks out.
Mainline `panel-raspberrypi-touchscreen.c` uses 25.9794 MHz for the same panel family; this unit
was run at 30 MHz.

**Polarity gotcha.** Both syncs are active-low here, so `NHSYNC | NVSYNC`. Mainline
`tc358762_init()` turns those flags into `LCDCTRL_HSPOL | LCDCTRL_VSPOL`, giving
`LCDCTRL = 0x001a0150`. The Lyra blob writes `0x00100152` — **no polarity bits at all**
(Rockchip handles polarity further up the pipe). If the image comes up shifted, rolling, or
torn, `LCDCTRL` polarity is the first knob to try.

The vendor extras decode as DPI timing, which supports leaving them in if mainline's init alone
doesn't light the panel: `0x0428 = 0x00690320` (low half = 800 = hactive),
`0x0430 = 0x000701e0` (low half = 480 = vactive).
