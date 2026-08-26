# Context — RetroBPI_M2M

> Port of the **LyraZeroW SuperRetroPack** retro-gaming firmware from the Luckfox Lyra Zero W
> (Rockchip RK3506B) to the **Banana Pi BPI-M2 Magic** (Allwinner R16/A33).
> Reference project: `C:\LuckFox_Projects\LyraZeroW_SuperRetroPack`
> Started: 2026-08-10

---

## Hardware Summary — BPI-M2 Magic (BPI-M2M)

| Item | Detail |
|---|---|
| Board | Banana Pi BPI-M2 Magic, 51×51 mm, 48 g |
| SoC | Allwinner **A33** (this board) — 4× Cortex-A7. Pin-compatible with the R16 variant. |
| GPU | **Mali-400 MP2** (OpenGL ES 2.0) — vendor spec table wrongly says PowerVR SGX544 |
| RAM | 512 MB DDR3 (shared with GPU) — same budget as the Lyra |
| Storage | **8 GB onboard eMMC** + microSD slot |
| PMIC | AXP223 |
| Wireless | AP6212 — Wi-Fi 802.11 b/g/n + BT 4.0 (BCM43438 in mainline DT) |
| Display | **MIPI DSI, 4-lane**, connector **CN2 (24-pin)**. Also LVDS on the 40-pin header. |
| Camera | CSI, 24-pin CN3 |
| USB | 1× USB 2.0 host, 1× USB OTG |
| Audio | On-board mic, 3.5 mm jack (AC100/analog codec in DT) |
| GPIO | 40-pin, RPi B+ compatible layout |
| **No HDMI** | Display bring-up is blind — serial console is mandatory |
| **No Ethernet** | Wi-Fi only |
| Power | 5 V @ 2 A via DC or micro-USB (OTG) |
| Debug UART | CON3: P1 GND, P2 UART0-RX, P3 UART0-TX (115200 8N1) |

### CN2 — MIPI DSI connector pinout (from vendor docs)

| Pin | Signal | GPIO | Pin | Signal | GPIO |
|---|---|---|---|---|---|
| 1 | DSI-D0N | | 2 | DSI-D0P | |
| 3 | DSI-D1N | | 4 | DSI-D1P | |
| 5 | DSI-CKN | | 6 | DSI-CKP | |
| 7 | DSI-D2N | | 8 | DSI-D2P | |
| 9 | DSI-D3N | | 10 | DSI-D3P | |
| 11 | NC | | 12 | NC | |
| 13 | **TP-SDA** | PH3 | 14 | **TP-SCK** | PH2 |
| 15 | TP-INT | PB5 | 16 | TP-RST | PB6 |
| 17 | LCD-BL-EN | PL4 | 18 | LCD-RST | PL5 |
| 19 | LCD-PWR-EN | PB7 | 20 | LCD-PWM | PH0 |
| 21 | GND | | 22 | GND | |
| 23 | "PS" | ? | 24 | "PS" | ? |

**Open items on CN2** (must be answered from the schematic, not the wiki table):
- CN2 carries **no explicit 3V3 or 5V rail** — pins 23/24 are labelled only "PS". RPi DSI panels
  need 5 V (official 7" backlight draws ~500 mA). Confirm what "PS" is; if it is not a usable
  supply, the adapter must take 5 V from the 40-pin header.
- CON1-P02/P04 are labelled **DCIN**, not regulated 5 V — that is the raw barrel/USB input ahead
  of the PMIC. Measure it before using it as panel power.
- Which TWI controller PH2/PH3 belong to (TWI1 is on PH4/PH5 per the 40-pin table, so PH2/PH3 is
  most likely TWI0) — needed for the DT `&i2c` node.

Schematic / Gerber (vendor, Google Drive links on the docs page):
https://docs.banana-pi.org/en/BPI-M2_Magic/BananaPi_BPI-M2_Magic

### Target display — Waveshare 5inch DSI LCD (B)

Same panel already working on the Lyra. Connected via a custom **CN2 24-pin → RPi 15-pin FFC
flex adapter**. Drop the adapter design (schematic / Gerber / pin map) in `docs/dsi_adapter/`.

| Property | Value | Source |
|---|---|---|
| Resolution | 800×480 IPS, 60 Hz | Waveshare wiki |
| DSI lanes | **1** (2 lanes = white screen) | Lyra devlog 2026-05-29 |
| Bridge | **TC358762** DSI→DPI, needs a DSI init sequence | Lyra devlog |
| Panel MCU | I2C **0x45** — power-on + backlight (0–255) | Lyra devlog |
| Touch | **FT5x06 @ I2C 0x38**, driver `edt-ft5x06` | Lyra devlog (newer revs ship GT911 @ 0x14 — enable both drivers) |
| Pixel clock | 30 MHz (Lyra, proven) / 25.9794 MHz (mainline RPi value) | Lyra devlog / `panel-raspberrypi-touchscreen.c` |
| Power | **~1.3 W, taken from the DSI ribbon** — no separate supply | Waveshare wiki FAQ |

**It is an RPi-official-7"-compatible panel.** Waveshare's own instructions are
`dtoverlay=vc4-kms-dsi-7inch` — the same overlay as the genuine RPi 7" touchscreen. So the
mainline RPi panel drivers are the right starting point, not `panel-waveshare-dsi`
(that driver's `waveshare,5.0inch-panel` is the **5inch DSI LCD (D)** — 720×1280, 2-lane —
a different product).

### The adapter — "bpi24-dsi-flex" Rev F (built, verified)

Source: `C:\Users\97254\My Drive\פרוייקטים\BPI_M2M_DSI_24pToRPI_15p`
2-layer flex, 45 × 23 mm, 25 µm core, ENIG, 0.25 mm PI stiffener on B side.
Both finger arrays on F.Cu; the 15-way connector is rotated 180° vs CN2, so every pair
physically crosses its own legs with matched via counts and B.Cu length
(intra-pair mismatch: D0 0.0000 mm, D1 0.0015 mm, CK 0.0000 mm).

Netlist (from `build_flex.py`):

| CN2 | net | RPi 15-way |
|---|---|---|
| 1 / 2 | D0_N / D0_P | 8 / 9 |
| 3 / 4 | D1_N / D1_P | 2 / 3 |
| 5 / 6 | CK_N / CK_P | 5 / 6 |
| 13 / 14 | SDA / SCL | 12 / 11 |
| 21 / 22 | GND | 1, 4, 7, 10, 13 |
| — | 3V3 (external solder ear) | 14 / 15 |

**Pin map verified.** The panel side matches the published RPi DSI (S2) pinout exactly —
1 GND, 2/3 Data Lane 1, 4 GND, 5/6 Clock, 7 GND, 8/9 Data Lane 0, 10 GND, 13 GND, 14/15 +3V3.
Note this is **not** the CSI 15-pin order (which is D0 / D1 / CLK with SCL/SDA on 13/14) — the
DSI connector genuinely puts Data Lane 1 first and doubles up 3V3 on 14/15. The CN2 side matches
the vendor CN2 table. Host lane 0 reaches panel lane 0, which is the one this 1-lane panel uses.

**Deliberately isolated:** CN2 7–12 (D2/D3, NC), 15–20 (TP-INT, TP-RST, LCD-BL-EN, LCD-RST,
LCD-PWR-EN, LCD-PWM), 23–24 (PS). This mirrors the RPi DSI connector, which has no pins for any
of them — panel reset, bridge power and backlight all go through the 0x45 MCU.

Consequences for software, both load-bearing:

1. **Touch must be polled.** There is no INT pin on the RPi DSI connector, so the cable cannot
   carry one — and mainline `edt-ft5x06.c` calls `devm_request_threaded_irq(&client->dev,
   client->irq, ...)` unconditionally, with no polling path. The RPi kernel carries a downstream
   polling patch (`work_i2c_poll` + `edt_ft5x06_ts_irq_poll_timer`, guarded by `if (client->irq)`),
   which is why RPi's `edt-ft5406.dtsi` has no `interrupts` property and still works.
   **Backporting that patch is mandatory**, not optional.
2. **No panel GPIOs.** Panel reset, bridge power-on and backlight all come from the 0x45 MCU
   (RPi's overlay uses `reset-gpio = <&reg_display 1 1>` — the ATTINY is also a gpio-controller).
   Any DTS that reaches for PL5 / PB7 / PL4 / PH0 is wrong.

**Panel power:** 3V3 is injected externally at the solder ear on the top edge — the cable does
not take it from CN2. The panel draws ~1.3 W ≈ 400 mA at 3.3 V. Budget that against the AXP223
3V3 rail before tapping CON1-P01/P17, and star the ear's ground back to the board directly
(as the fab notes already say).

### The mainline blocker: sun6i DSI accepts panels, not bridges

`sun6i_dsi_attach()` in `drivers/gpu/drm/sun4i/sun6i_mipi_dsi.c` is:

```c
struct drm_panel *panel = of_drm_find_panel(device->dev.of_node);
if (IS_ERR(panel)) return PTR_ERR(panel);
dsi->panel = panel;
```

It only binds a **`drm_panel` registered against the DSI child node**. There is no
`drm_of_find_panel_or_bridge`, no `devm_drm_of_get_bridge`, and it builds its own
`drm_connector` instead of using a bridge chain. Consequences:

- **`tc358762` (bridge driver) cannot attach.** It registers a `drm_bridge`, so
  `of_drm_find_panel()` never matches. RPi's `vc4-kms-dsi-7inch` arrangement
  (`bridge@0` under the DSI host → `panel-simple` downstream) does not port over as-is.
- **`panel-raspberrypi-touchscreen` cannot attach either.** It is an *I2C* driver: the panel is
  registered against the i2c node, while the DSI device it creates gets
  `info.node = of_graph_get_remote_port(endpoint)` — a port node under `&dsi`. The two of_nodes
  differ, so `of_drm_find_panel()` misses.

**Chosen fix — write a small DSI-native panel driver** (`panel-waveshare-dsi-b.c`, ~250 lines,
mostly lifted from the GPL `panel-raspberrypi-touchscreen.c`):
- a `mipi_dsi_driver` probing as a **child of `&dsi`** (`reg = <0>`), so `of_drm_find_panel()` hits
- `lanes = 1`, `MIPI_DSI_FMT_RGB888`, `VIDEO | VIDEO_SYNC_PULSE | LPM | VIDEO_HSE`
- `prepare()`: power-on via I2C 0x45, then the TC358762 init writes
- backlight device writing the PWM register on 0x45
- `get_modes()`: 800×480@60

Alternative (cleaner, more work, upstreamable): patch `sun6i_mipi_dsi.c` to support bridges, then
use stock `tc358762` + `panel-simple` exactly like the RPi overlay.

Touch is independent of all this — a plain `edt-ft5x06` I2C node at 0x38.

### Harvested from the working Lyra build — see `docs/waveshare_5b_panel_reference.md`

Done: the **16-command TC358762 init sequence** (decoded against mainline's register map),
the **0x45 MCU register map** (all three modes the vendor driver supports), and the
**`ws_800_480` timings** (30 MHz, 978 × 511 → 60.03 Hz, both syncs active-low).

Still outstanding — needs the Lyra powered and on ADB:

**Which 0x45 mode does our unit use?** The vendor driver picks at runtime by reading register
`0x80`. `0xde`/`0xc3` → the genuine RPi ATTINY map, and mainline `rpi-panel-attiny-regulator`
drops in unmodified. Anything else → the Waveshare clone map (`0xc0/0xc2/0xac/0xad`, inverted
brightness on `0xab`/`0xaa`), which mainline does not implement and we would have to port.

```bash
adb shell "i2cdetect -l"
adb shell "i2cget -y <bus> 0x45 0x80; i2cget -y <bus> 0x45 0x97"
```

---

## Software situation — the decision that shapes everything

### Vendor images: all kernel 3.4.39

Every official BPI-M2M image (Android 6, Ubuntu 16.04 Mate/Server up to the 2021-03-24 release,
Tina Linux) runs the **Allwinner sunxi-3.4 BSP**. Consequences:

- No DRM/KMS — display is the BSP `disp2` fbdev stack. The Lyra launcher (DRM dumb buffers +
  page flip) and RetroArch's `drm` video driver **cannot run**.
- Panels are hardcoded C files under `drivers/video/sunxi/disp2/disp/lcd/` plus `sys_config.fex`.
  No TC358762 / RPi panel support at all.
- Mali-400 needs the old r6p2 fbdev blob; no lima/mesa.
- Ubuntu 16.04 userspace is EOL — building RetroArch and cores against it is painful.

### Mainline: the display pipeline is already upstream

Verified against current `torvalds/linux` master:

| Piece | Status |
|---|---|
| Board DTS `sun8i-r16-bananapi-m2m.dts` | Upstream. **Already an A33 device tree despite the filename** — it `#include`s `sun8i-a33.dtsi` and declares `compatible = "sinovoip,bananapi-m2m", "allwinner,sun8i-a33"`. Our board is the A33 variant, so no change is needed. eMMC, SD, USB, Wi-Fi (BCM43438), BT, audio codec, AXP223 all enabled. |
| `sun8i-a33.dtsi` | Has `dsi@1ca0000` (`allwinner,sun6i-a31-mipi-dsi`), `dphy@1ca1000`, and `tcon0` → DSI endpoint already wired. |
| `sun6i_mipi_dsi.c` | **No lane-count restriction** — `lanes_mask = GENMASK(device->lanes - 1, 0)`; 1-lane is fine. Non-burst path emits HSS/HSE sync packets → matches the RPi panel's SYNC_PULSE mode. |
| RPi panel drivers | `panel-raspberrypi-touchscreen` in mainline; also the split `tc358762` bridge + `rpi-panel-attiny-regulator` + `panel-simple` path. |
| Mali-400 MP2 | **lima** in mainline mesa → real GLES2. A capability the RK3506B did not have. |
| U-Boot | `Bananapi_m2m_defconfig` upstream. |

**What is missing:** the board DTS has **zero display nodes** — no `&dsi`, `&dphy`, `&tcon0`,
panel, backlight, or touch. Writing those is our job, exactly as on the Lyra.

### No prebuilt mainline image exists

Armbian has **no `bananapim2m` board config** (checked `armbian/build` `config/boards` — only
m2, m2plus, m2pro, m2s, m2ultra, m2zero). So there is no download-and-go mainline image; we build.

---

## Plan

### Step 0 — Hardware sanity (throwaway, ~1 h)
Flash the vendor **Ubuntu 16.04 Server, kernel 3.4.39, 2021-03-24** image (server, not Mate).
Purpose only: prove the board boots, eMMC/SD/Wi-Fi/USB/audio are alive, and get a serial console.
Do **not** attach an RPi DSI panel to this image — it has no driver for it.

**Serial console caveat:** vendor docs note SD-card pins and UART0 overlap on some builds, and
the 2019 eMMC image was published specifically to free UART0 for debug. If UART0 on CON3 is
silent, try **UART2** before concluding the board is dead.

### Step 1 — Mainline bring-up
Mainline U-Boot (`Bananapi_m2m_defconfig`) + mainline kernel + a Debian/Ubuntu armhf rootfs.
Easiest route: the **Armbian build framework with a hand-written `bananapim2m` board config**
(gives apt, `modetest`, `evtest`, `edid-decode`, mesa/lima for debugging). Verify headless first:
serial console, eMMC, Wi-Fi, USB gamepad.

### Step 2 — DSI panel bring-up

**First light: consider the EK79007 (ESP32-P4 7" 1024×600) instead of the Waveshare (B).**
It is a plain DSI panel with a 7-command DCS init, so it attaches to sun6i natively — no bridge,
no I2C-probed panel, none of the workarounds below. It is also 2-lane (validates the D1 pair) and
its GT911 touch has a real INT line (no `edt-ft5x06` polling backport needed). Cost is four flying
wires from the adapter board's J6 header. Full spec: `docs/ek79007_panel_port.md`.
The Waveshare 5" (B) remains the better *product* panel at 800×480.

**Waveshare 5" DSI LCD (B) path:**
1. Harvest the three artifacts from the Lyra build (see above).
2. Write `panel-waveshare-dsi-b.c` as a DSI-native `drm_panel` (see the blocker section).
3. Board DTS: enable `&de`, `&tcon0`, `&dphy`, `&dsi`; add the panel as a child of `&dsi`
   with `reg = <0>`; add the I2C bus on PH2/PH3 with `edt-ft5x06` @ 0x38; wire
   LCD-RST (PL5) / LCD-PWR-EN (PB7) / BL-EN (PL4) / PWM (PH0) as needed.
   Draft: `configs/sun8i-r16-bananapi-m2m-lcd.dts`.
4. Validate with `modetest -M sun4i-drm` before anything else touches the display.

### Step 3 — Port the retro stack
Launcher (`launcher.c`, DRM dumb buffers + SDL2_ttf + evdev) and RetroArch port over largely
unchanged since both target DRM/KMS. Two deltas from the Lyra:
- **RGA2 → nothing / G2D.** Allwinner's 2D engine is different; the RGA2 code does not port.
- **lima gives us a GPU.** RetroArch's `gl` driver with GPU scaling and shaders is likely a
  better answer than the Lyra's hand-written NEON + DRM-plane scaling. Evaluate `gl` vs `drm`.

### Step 4 — Product image
Switch to **Buildroot** for the shipping image (mirrors the Lyra workflow: custom defconfig,
rootfs overlay, RetroArch package, launcher, fast boot). No BPI-M2M defconfig exists upstream,
but mainline U-Boot + kernel DTS make it a short one.

---

## Deltas vs the Lyra project

| | Lyra Zero W (RK3506B) | BPI-M2 Magic (R16/A33) |
|---|---|---|
| CPU | 3× A7 @ 1.2 GHz | 4× A7 |
| GPU | none | **Mali-400 MP2 (lima)** |
| RAM | 512 MB | 512 MB |
| Storage | SD only | **8 GB eMMC** + SD |
| 2D accel | RGA2 (`/dev/rga`) | Allwinner G2D — different API, RGA2 code does not port |
| Display out | DSI 2-lane, 22-pin | DSI 4-lane, 24-pin CN2 |
| Vendor BSP | Luckfox Lyra SDK, kernel 6.1, DRM | kernel 3.4 only — **mainline required** |
| Audio | DSM DAC, never wired | 3.5 mm jack + codec in mainline DT |
| Debug | ADB over USB + serial @1.5 Mbps | serial @115200 (+ USB OTG) |

## Open questions

1. ~~Flex adapter~~ — **found and verified**: Rev F `bpi24-dsi-flex`, netlist checked against
   both the CN2 table and the published RPi DSI pinout. See the adapter section.
2. ~~Which panel~~ — **decided: Waveshare 5inch DSI LCD (B)**, the same unit running on the Lyra.
3. ~~R16 or A33~~ — **A33**. No software impact: the upstream DTS is already an A33 tree.
4. **0x45 MCU register map** — RPi-compatible or a Waveshare variant? Decides whether stock
   `rpi-panel-attiny-regulator` can be used verbatim and how much of
   `panel-raspberrypi-touchscreen.c` can be reused. Answer it on the Lyra.
5. **3V3 budget** — the panel needs ~400 mA at 3.3 V through the solder ear. Confirm the AXP223
   3V3 rail can carry it before tapping CON1-P01/P17, or feed the ear from its own regulator.
6. ~~PH2/PH3 → which TWI?~~ — **`i2c0`**. Confirmed in `sun8i-a23-a33.dtsi`:
   `i2c0_pins { pins = "PH2", "PH3"; }` and `i2c1_pins { pins = "PH4", "PH5"; }`, which also
   matches the vendor 40-pin table's TWI1 on PH4/PH5. The ribbon's I2C pair is `&i2c0`.
7. **Flying-wire GPIO choices** for J6 (LCD_RST → PH6, TP_RST → PB2, TP_INT → PH7,
   LED_CTRL → PH1). All four are unused in the base DTS and `pio` is an interrupt-controller with
   `#interrupt-cells = <3>`, so PH7 can carry the touch IRQ. Still needs checking against the
   R16/A33 manual pin-mux tables before soldering.
