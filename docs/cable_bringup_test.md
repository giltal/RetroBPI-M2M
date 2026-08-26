# Testing the bpi24-dsi-flex Rev F adapter

Three tests, in order. Each one is cheap and rules out a whole class of failure before the next
gets expensive.

---

## Test 0 — Continuity and isolation (no BPI, no power, do this first)

For a passive flex with no components on it, **continuity + isolation is the functional test.**
Nothing you run on the BPI adds information a meter doesn't, short of a TDR at the D-PHY rates,
which you can't do anyway.

First do the 1:1 paper check with `dryfit_template.pdf` and **number the fingers by physical
position from that template**. Doing it that way means the probe list below also catches a
mirrored or reversed tail, which is what bit Rev B and Rev E.

Expected connections:

| CN2 finger | net | 15-way finger |
|---|---|---|
| 1 | D0_N | 8 |
| 2 | D0_P | 9 |
| 3 | D1_N | 2 |
| 4 | D1_P | 3 |
| 5 | CK_N | 5 |
| 6 | CK_P | 6 |
| 13 | SDA | 12 |
| 14 | SCL | 11 |
| 21, 22 | GND | 1, 4, 7, 10, 13 |
| ear pad 1 | 3V3 | 14, 15 |
| ear pad 2 | GND | (ties to the GND set above) |

Must be **open**:
- CN2 7, 8, 9, 10 (D2/D3 — SoC outputs, do **not** ground them), 11, 12
- CN2 15, 16, 17, 18, 19, 20 (TP-INT, TP-RST, BL-EN, LCD-RST, PWR-EN, PWM)
- CN2 23, 24 (PS)
- **ear 3V3 to GND** — check this one explicitly, it is the failure that damages things
- every finger to its immediate neighbours on both tails

Probe at the vias or exposed track rather than flexing the tails repeatedly.

---

## Test 1 — I2C liveness (first Linux boot, works on any image)

The cable carries SDA/SCL and the 3V3 ear, and every RPi-style DSI panel has I2C devices on it.
So `i2cdetect` proves the I2C pair, the 3V3 feed, the ground return, and that the panel is alive
— **with no DSI, no display driver and no panel driver involved.** This works on the vendor
kernel 3.4 image; it does not need mainline.

Wire the ear to 3V3, star its ground back to the BPI board, seat both tails, then:

```bash
i2cdetect -l
```
Find the TWI on PH2/PH3 (bus number still to be confirmed — scan them all), then:
```bash
i2cdetect -y -r <bus>
```

Expected addresses:

| Panel | Should appear |
|---|---|
| Waveshare 5" DSI LCD (B) | `0x45` (panel MCU) and `0x38` (FT5x06 touch) |
| Waveshare 7" DSI LCD (C) | `0x45` and `0x14` or `0x5d` (GT911 touch) |

If both show up, 4 of the 9 nets plus power and ground are confirmed good and the panel has
power. If nothing shows up, suspect the 3V3 ear or the I2C pair before suspecting anything else.

On the vendor 3.4 image the TWI may need enabling in `sys_config.fex`, and `i2c-dev` loaded.

While you are here, settle the open question from `waveshare_5b_panel_reference.md`:
```bash
i2cget -y <bus> 0x45 0x80    # 0xde/0xc3 => RPi ATTINY map; else Waveshare clone map
i2cget -y <bus> 0x45 0x97
```

---

## Test 2 — Actual pixels

Only this exercises the three differential pairs. Needs mainline + the DSI device tree + a panel
driver, i.e. everything in Context.md Steps 1–2. `modetest -M sun4i-drm` is the check.

Note the 5" (B) is **1-lane** — it uses D0 and CLK only and will never exercise the D1 pair.
A 2-lane panel is the only way to validate the whole cable.

---

## Reference — RPi DSI 15-pin vs the ESP32-P4 LCD adapter board (J3)

They are **the same connector and the same pinout**. Espressif used the identical TE part
(`1-1734248-5`) that the Raspberry Pi A/B boards use, and cloned the assignment:

| Pin | RPi DSI (S2/DISP1) | ESP32-P4 LCD subboard J3 | Net on that board |
|---|---|---|---|
| 1 | GND | GND | |
| 2 | Data Lane 1 N | DN1 | ESP32_DATN1 |
| 3 | Data Lane 1 P | DP1 | ESP32_DATP1 |
| 4 | GND | GND | |
| 5 | Clock N | CLK_CN | ESP32_CLKN |
| 6 | Clock P | CLK_CP | ESP32_CLKP |
| 7 | GND | GND | |
| 8 | Data Lane 0 N | DN0 | ESP32_DATN0 |
| 9 | Data Lane 0 P | DP0 | ESP32_DATP0 |
| 10 | GND | GND | |
| 11 | SCL | SCL0 | ESP32_I2C_SCL |
| 12 | SDA | SDA0 | ESP32_I2C_SDA |
| 13 | GND | GND | |
| 14 | +3V3 | 3V3 | |
| 15 | +3V3 | 3V3 | |

Source: `esp32-p4-function-ev-board-lcd-subboard-schematics.pdf`, connector J3, `DSI_1-1734248-5`.

**This independently settles pins 11/12/13**, which the published RPi DSI tables leave ambiguous.
A schematic agrees with the assignment the Rev F cable was built to. That question is closed.

**Not on J3** — these live on the separate J6 header on the adapter board:
`RST_LCD` (→ ESP32 GPIO27), `PWM`/`LED_CTRL` (→ GPIO26, backlight enable), `INT_TP` (touch IRQ).
The board also has its **own USB-C** feeding `USB_5V → VCC_5V → LCD_VDD` and the backlight boost
converter — it is not powered solely from the ribbon's 3V3.

### Using it as a test load

**Good for Test 1.** Touch sits on the J3 I2C pair, so `i2cdetect` across the cable is a valid
check. Power the adapter from its own USB-C. If nothing appears, tie `RST_LCD` high on J6 — the
touch controller may be held in reset.

**Resolved: the subboard is a 3V3 sink.** It has no 3V3 regulator (`U2` is a 1.8 V LDO, `U3` is a
9.6 V boost), so `VDD_3V3` arrives from J3 pins 14/15. The cable's 3V3 ear **must** be powered and
there is no supply conflict. The board separately needs 5 V on its own USB-C — see
`ek79007_panel_port.md`.

**Poor for Test 2.** EK79007 is 2-lane and needs a DCS init sequence, and there is **no mainline
Linux panel driver** for it. Worse, reset and backlight are only reachable via J6, which this
cable does not carry — so the panel would likely never leave reset and the backlight would never
light. Use the Waveshare 5" (B) for pixels; its init sequence is already harvested.

### If instead it is a Waveshare 7" DSI LCD (C)

1024×600, 2 lanes, 50 MHz, `MIPI_DSI_MODE_VIDEO | VIDEO_HSE | CLOCK_NON_CONTINUOUS`, supported by
`panel-waveshare-dsi.c` as `waveshare,7.0inch-c-panel` (RPi tree, not mainline — and it is an
I2C-probed driver, so it hits the same sun6i attach problem described in Context.md).
That one **would** be the better Test 2 target, since being 2-lane it exercises the D1 pair that
the 5" (B) never touches.
