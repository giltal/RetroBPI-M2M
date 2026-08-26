# EK79007 (ESP32-P4 7" 1024×600) — Linux panel port spec

Harvested from `C:\Users\97254\My Drive\ArduinoProjects\ESP32_P4\ESP32_P4_BaseProject` and the
upstream driver it calls into
(`esp-arduino-libs/ESP32_Display_Panel`, `src/drivers/lcd/port/esp_lcd_ek79007.c`).

## Why this is now the best first bring-up target

`sun6i_dsi_attach()` only binds a `drm_panel` registered against the DSI **child node**. That is
what made both Waveshare options awkward:

| Panel | Structure | sun6i |
|---|---|---|
| Waveshare 5" (B) | TC358762 **bridge** + I2C MCU | ✗ registers a `drm_bridge` — no attach |
| Waveshare 7" (C) | `panel-waveshare-dsi`, **I2C-probed** | ✗ panel of_node ≠ DSI device of_node |
| **EK79007** | **plain DSI panel, DCS init** | ✓ **attaches natively** |

EK79007 is a direct DSI panel with a DCS init sequence and a reset GPIO. Nothing else. A Linux
driver is a `mipi_dsi_driver` that lives as a child of `&dsi` — exactly the shape sun6i wants.
No bridge work, no I2C-probe indirection, no patched attach path.

Two more wins:
- **2 lanes** → exercises the D1 pair, which the 1-lane 5" (B) can never validate.
- **GT911 touch with a real INT line** → mainline `goodix` binds normally, so the
  `edt-ft5x06` polling backport is not needed for this panel.

Cost: four flying wires from the adapter board's J6 header to BPI GPIOs.

---

## DSI configuration

```c
dsi->lanes      = 2;
dsi->format     = MIPI_DSI_FMT_RGB888;
dsi->mode_flags = MIPI_DSI_MODE_VIDEO;   /* try adding _VIDEO_SYNC_PULSE, then _VIDEO_BURST */
```

Lane rate: 52 MHz × 24 bpp / 2 lanes = **624 Mbps/lane**. (The ESP project configures the PHY at
1000 Mbps — that is headroom, not a requirement.) Well within what the A33 D-PHY does.

`mode_flags` is the one genuinely unknown. Espressif's stack drives DPI and does not expose the
DSI video-mode variant. VPW = 1 hints at sync-pulse. Start with plain `MIPI_DSI_MODE_VIDEO`;
if the image tears or rolls, add `MIPI_DSI_MODE_VIDEO_SYNC_PULSE`, then try burst.

## Display mode

From the sketch: DPI clock 52 MHz, HPW 10 / HBP 160 / HFP 160, VPW 1 / VBP 23 / VFP 12.

```c
static const struct drm_display_mode ek79007_mode = {
	.clock       = 52000,                    /* kHz */
	.hdisplay    = 1024,
	.hsync_start = 1024 + 160,               /* 1184 */
	.hsync_end   = 1024 + 160 + 10,          /* 1194 */
	.htotal      = 1024 + 160 + 10 + 160,    /* 1354 */
	.vdisplay    = 600,
	.vsync_start = 600 + 12,                 /*  612 */
	.vsync_end   = 600 + 12 + 1,             /*  613 */
	.vtotal      = 600 + 12 + 1 + 23,        /*  636 */
};
```

52 MHz / (1354 × 636) = **60.4 Hz**.

## Init sequence — all of it

Seven vendor DCS writes then sleep-out. That is the entire panel init:

```c
static void ek79007_init_seq(struct mipi_dsi_device *dsi)
{
	mipi_dsi_dcs_write_seq(dsi, 0x80, 0x8B);
	mipi_dsi_dcs_write_seq(dsi, 0x81, 0x78);
	mipi_dsi_dcs_write_seq(dsi, 0x82, 0x84);
	mipi_dsi_dcs_write_seq(dsi, 0x83, 0x88);
	mipi_dsi_dcs_write_seq(dsi, 0x84, 0xA8);
	mipi_dsi_dcs_write_seq(dsi, 0x85, 0xE3);
	mipi_dsi_dcs_write_seq(dsi, 0x86, 0x88);

	mipi_dsi_dcs_exit_sleep_mode(dsi);   /* 0x11 */
	msleep(120);
}
```

Note the vendor driver sends **no `DISPON` (0x29)** — init ends at sleep-out. Adding
`mipi_dsi_dcs_set_display_on()` is probably harmless, but if the panel misbehaves, drop it, since
that matches the reference exactly.

## Reset timing

```
assert reset    -> 10 ms
release reset   -> 20 ms
```

Reset polarity is configurable in the ESP driver (`flags.reset_active_high`); confirm the active
level from the sketch's `EXAMPLE_LCD_RST_ACTIVE_LEVEL` before trusting `GPIO_ACTIVE_LOW`.

## Touch — GT911

From the sketch: 1024×600, I2C at 400 kHz, addresses **0x5D (default) / 0x14**, with RST and INT
both wired. On GT911 the **INT level during reset release selects the I2C address**, so both lines
must be driven — this is not optional.

Mainline `drivers/input/touchscreen/goodix.c` handles GT911 with `irq-gpios` and `reset-gpios`.

## Wiring required (J6 header on the LCD adapter board)

The 15-way ribbon carries only the DSI lanes, I2C, GND and 3V3. These four live on **J6**, a
2×4 `CON4X2` header, and need flying wires to BPI 40-pin GPIOs:

| Signal | Purpose |
|---|---|
| `RESET_LCD` | panel reset (ESP default GPIO27) |
| `RESET_TP` | GT911 reset (ESP default GPIO32) |
| `INT_TP` | GT911 interrupt + address select (ESP default GPIO33) |
| `LED_CTRL` | backlight enable / PWM (ESP default GPIO26) |

Also present near J6: `SHLR`, `UPDN`, `STBYB` — EK79007 scan-direction and standby straps.

> **I could not reliably map these to J6 pin numbers** from a text extraction of the schematic.
> Read them off the board silkscreen or open
> `esp32-p4-function-ev-board-lcd-subboard-schematics.pdf` directly before soldering.

For a first light, `LED_CTRL` can simply be tied to its active level rather than PWM'd. Later it
can go to a real PWM — CON1-P07 is PWM1 (PH1) on the BPI 40-pin header, usable with
`pwm-backlight`.

## Power — the board needs **both** rails

Two independent supplies, and it will not work on either alone:

| Rail | Source | Feeds |
|---|---|---|
| **3V3** | **J3 pins 14/15** — i.e. the ribbon, from the BPI | `VDD_3V3`: logic, pull-ups, `U2` |
| **5V** | the subboard's **own USB-C (J1)** | `USB_5V → VCC_5V →` boosts |

Confirmed from the schematic:
- `U3` = **AP3012K** boost, `VIN = VCC_5V`, out **9.6 V** → `LCD_AVDD` (via L2 10 µH + D5 Schottky)
- `U2` = **ME6211C18M5G-N** — a **1.8 V** LDO
- **There is no 3V3 regulator anywhere on the subboard.** `VDD_3V3` therefore arrives *from J3*.

**This closes the source-vs-sink question.** The subboard is a 3V3 **sink**, exactly like an RPi
panel. The cable's 3V3 solder ear **must** be powered — there is no supply conflict to worry about.
Draw on 3V3 is also modest here (logic and pull-ups only), unlike the Waveshare (B) which runs its
backlight off the ribbon at ~400 mA.

### The USB-C is a sink, not a source

`J1` has **5.1 kΩ(1%) on CC1 and CC2** — textbook Rd pull-downs. That is a device declaring
itself a power *consumer*. It is meant to be fed, and any compliant USB-C source should give it
5 V.

So a reading of ~0.5 V means it is not being fed. Ladder:

1. Measure VBUS **at the connector** (`A4_VBUS` / `B9_VBUS` pads). If it is 0 V there, the problem
   is upstream — try a plain **USB-A → C** cable from a phone charger, which puts 5 V on VBUS with
   no CC negotiation at all. That rules out cable and CC issues in one step.
2. If VBUS is good at the connector but the downstream rail is ~0.5 V, something on `VCC_5V` is
   pulling it into current limit — check `D1` (DSS24) and the `U3` boost input for a short.
3. A USB power meter inline will show whether the source is even attempting to deliver current.

### Powering the panel from the BPI

The BPI 40-pin header has **no regulated 5 V pin** — `CON1-P02` and `P04` are **DCIN**, the raw
5 V input rail ahead of the AXP223 (the board is specified as 5 V @ 2 A via DC jack or micro-USB).
So DCIN is tappable as a ~5 V source, but it is unregulated and shared with the whole board.

**Prefer a separate 5 V supply for the panel during bring-up**, grounded back to the BPI (star to
the board ground, per the cable's fab notes). Rationale: the panel drives a 9.6 V boost plus a
backlight boost, and inrush browning out the BPI mid-boot is a miserable failure to debug on a
board with no HDMI and only a serial console. It also keeps a panel fault from taking down the
machine you are debugging on.

3V3 for the ear comes from `CON1-P01` or `P17`.

## Open items

1. `mode_flags` video variant (see above).
2. Reset active level.
3. J6 pin numbering.
4. Whether J3 pin 14 is a source or a sink.
5. 1024×600 is fine for bring-up, but 800×480 remains the better final target for the console —
   less framebuffer, less scaling work, and it matches the Lyra launcher's assumptions.
