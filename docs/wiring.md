# CON1 (40-pin header) wiring

Everything the DSI panel needs that the flex cable does **not** carry, plus power.

The ribbon already carries the DSI lanes, the touch/panel I2C (PH2/PH3 = `i2c0`), GND and the
3V3 ear. Nothing else about the display touches this header.

## Panel control — four flying wires from the adapter board's J6

These match `kernel/sun8i-a33-bananapi-m2m-ek79007.dts`. Change one and you change the other.

| From (J6 on LCD adapter) | To (CON1 pin) | GPIO | Purpose |
|---|---|---|---|
| `LED_CTRL` | **P07** | PH1 | backlight enable (`gpio-backlight`) |
| `RESET_LCD` | **P11** | PH6 | EK79007 reset, active low |
| `INT_TP` | **P13** | PH7 | GT911 interrupt |
| `RESET_TP` | **P16** | PB2 | GT911 reset — **and** I2C address select |

`RESET_TP` is not optional: on the GT911 the INT level at the moment reset is released chooses
between address 0x5D and 0x14. Both lines must be driven or the address is undefined.

P07 is also PWM1, so real PWM dimming is available later via `&pwm` + `pwm-backlight` without
moving the wire. For first light `gpio-backlight` is enough.

## Panel power — the flex cable's solder ear

| Signal | CON1 pin |
|---|---|
| 3V3 (ear) | **P01** or **P17** |
| GND (ear) | any of P06 / P09 / P14 / P20 / P25 / P30 / P34 / P39 — **star to one point** |

The panel's **5 V** does not come from this header. It comes from the LCD adapter board's own
USB-C. See `strategy.md`.

## Optional: powering the board through the header

`CON1-P02` and `P04` are the net **`ACIN`** — the AXP223's charger input, shared with the `CN12`
barrel jack. It is an **input**. You can feed a clean 5 V in here to power the board (which keeps
the panel's current out of the micro-USB connector), but nothing ever comes *out* of it. That is
why it measures 0 V when the board is powered over micro-USB.

## Do not connect

| Pins | Why |
|---|---|
| **P03 / P05** | PH5/PH4 = TWI1 (`SENSOR-SDA`/`SENSOR-SCK`). The panel/touch I2C is PH2/PH3 (`i2c0`) and already runs through the flex cable. Do not duplicate it here. |
| P08 / P10 | console pins in principle — but see below, they are unpopulated |
| P15, P22, P26–P29, P31–P33, P36 | LVDS pins (PD18–PD27) — unused, leave alone |
| P02 / P04 | `ACIN`, input only, see above |

## The serial console is NOT on the header by default

Confirmed from the CON1 sheet: pins 8 and 10 reach PB0/PB1 **through `R104` and `R105`, both
marked `NC\0R` — not fitted.** So although the silkscreen calls them `UART0-TX`/`UART0-RX`, they
are open circuit as shipped.

Worse: mainline muxes uart0 to `uart0_pb_pins` (PB0/PB1), and U-Boot does the same via the DT —
`Bananapi_m2m_defconfig` does not set `CONFIG_UART0_PORT_F`, whose help text says the PF2/PF4
option "can be only booted in the FEL mode" because it takes over the SD card pins. So **nothing
in this build drives UART on PF2/PF4, and CON3 is silent regardless of whether a card is in.**

**The console is on CON1 P08 / P10, and needs no rework.** From the CON1 sheet:

```
CON1 pin 8  -> UART2-TX_C <-[ Q2 BSN20, R96 10K -> VCC-3V0 ]<- UART2-TX = PB0
CON1 pin 10 -> UART2-RX_C <-[ Q3 BSN20, R99 10K -> VCC-3V0 ]<- UART2-RX = PB1
```

PB0/PB1 reach the header through **BSN20 MOSFET level shifters**. `R104`/`R105` are an optional
*bypass* around those shifters, not the only path — an earlier revision of this document read them
as the sole connection and wrongly called fitting them mandatory.

The PB sheet confirms the mux: `PB0/UART2_TX/UART0_TX/PB_EINT0` and
`PB1/UART2_RX/UART0_RX/PB_EINT1` — the same pins mainline drives via `uart0_pb_pins`.

| | |
|---|---|
| **P08** | board TX → adapter RX |
| **P10** | board RX ← adapter TX |
| GND | P06 / P09 / P14 / P20 / P25 / P30 / P34 / P39 |
| Baud | 115200 8N1 |

If the signal is garbled or marginal, the BSN20 shifters are the suspect — they are effectively
open-drain and depend on pullups, with only the PB side pulled up by R96/R99. That is when fitting
R104/R105 to bypass them becomes worthwhile.

### Locating R104 / R105 (only if bypassing the level shifters)

From the vendor's own pick-and-place (`board_layout/place_txt.txt`, units MILS):

| Ref | X | Y | Rot | Package | Side |
|---|---|---|---|---|---|
| CON1 | -3245.00 | 240.00 | 0 | DIP40-254 | top |
| **R104** | **-2854.00** | **-15.50** | 90 | R0402 | **bottom** |
| **R105** | **-2808.50** | **-15.50** | 90 | R0402 | **bottom** |
| Q4 | -3210.00 | -408.00 | 90 | SOT-23 | bottom |

**They are on the underside of the board.** The `m` flag in the place file means mirrored, and
both designators appear only in `BPi-M2M-V1_2_assembly_bot.pdf`, not the top drawing.

Relative to CON1's origin: about **+9.9 mm** and **+11.1 mm** in X, **-6.5 mm** in Y — mirrored in
X when you flip the board over to look at them.

Easiest visual signature: the two are only **1.16 mm (45.5 mil) apart**, same 90° orientation, and
**both unpopulated** — so you are looking for a pair of adjacent empty 0402 footprints on the
bottom, near the 40-pin header, with the Q4/Q5 USB switch cluster as a nearby landmark.

Confirm with a meter before soldering: one pad of each footprint should ring out to CON1 P08 and
P10 respectively. And check P08 against CON3 pin 3 — if they are already common, fitting R104
would tie PB0 to PF2 (SDC0_CLK) and cause a bus fight.

Drawings and BOM are in `docs/board_layout/`.

(An earlier revision of this document claimed P08/P10 carried the same signals as CON3 and could
be used as a fallback. That was wrong — the DT mux is right, but the board leaves the connection
depopulated.)

For completeness on the naming: the vendor table labels P08/P10 "UART2-TX/RX", but the SoC pins
are PB0/PB1 and our DTS muxes them as `uart0` via `uart0_pb_pins`. The vendor warning about UART0
clashing with the SD card refers to the *other* mux option, `uart0_pf_pins` (PF2/PF4), which
really are SDC0 pins. Mainline uses the PB route, so this build has no SD/console conflict.

## Gamepad

USB-A port, not the header. If ADB is in use over the micro-USB, that port stays free for the
controller.
