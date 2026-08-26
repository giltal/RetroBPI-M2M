# Build strategy

**Decision: Buildroot, single stage. No distro bring-up phase.**

## Why Buildroot, and why not the alternatives

The instinct is to bring up on Debian/Armbian for the debugging comfort and switch to Buildroot
later. That's wrong here, because the premise doesn't hold: **there is no prebuilt image for this
board in any distro.** Armbian has no `bananapim2m` config. So U-Boot and the kernel get built by
hand regardless — the only thing a distro would change is the rootfs, and the rootfs is not where
the pain is. The pain is kernel, DTS, and a panel driver, and that work is identical either way.

Meanwhile Buildroot wins on the thing that is actually a hard requirement:

| | Buildroot | Armbian/Debian | Yocto |
|---|---|---|---|
| Sub-10 s boot | natural | fighting systemd the whole way | possible |
| Reuse of Lyra work | **direct** (`retroarch.mk`, patches, overlay, launcher) | rework | rework |
| Build time | ~1 h first, minutes incremental | n/a | hours |
| Debug tooling | add packages up front | `apt install` | packages |

The one real Buildroot cost — "I need a tool I didn't anticipate and now it's a 20-minute
rebuild" — is cheap to neutralise: put the whole bring-up toolkit in the defconfig on day one
(`libdrm` tests/`modetest`, `evtest`, `i2c-tools`, `edid-decode`, `strace`, `devmem2`,
`alsa-utils`, `mesa-demos`). Then you never reach for the escape hatch.

There is no BPI-M2M defconfig upstream, but adding one is short — mainline U-Boot has
`Bananapi_m2m_defconfig` and the kernel has the DTS, so it is essentially
`BR2_TARGET_UBOOT_BOARDDEFCONFIG="Bananapi_m2m"` plus
`BR2_LINUX_KERNEL_INTREE_DTS_NAME="allwinner/sun8i-r16-bananapi-m2m"` and the usual ARM/toolchain
lines.

## Storage architecture — SD only

**This board has no eMMC populated**, despite the 8 GB in the published spec. Everything lives on
one SD card. (Worth a one-line confirmation once it boots — `dmesg | grep mmc` — because if an
eMMC does enumerate, moving the rootfs onto it is a straight win.)

Single card, three partitions:

| Part | Contents | Format |
|---|---|---|
| — | U-Boot SPL + U-Boot | raw, sector 16 (8 KB offset), sunxi convention |
| p1 | kernel + DTB | FAT or ext4, small |
| p2 | rootfs | **squashfs, read-only** |
| p3 | ROMs, saves, states, config | ext4, the only writable area |

Losing the eMMC removes the "OS on non-removable media" protection, which makes the rest of this
**more** important, not less. The Lyra lost a build to SD corruption (fstrim on a cheap card), and
that failure mode is now back on the table. Mitigations:

- **Read-only squashfs rootfs.** The overwhelming majority of the card is then never written at
  all, so an unclean power-off — which is how a console is *always* switched off — cannot corrupt
  the system. This is the single biggest lever.
- Squashfs also reads less from a slow medium than ext4 (Lyra: 176 MB ext4 vs 42 MB squashfs), and
  it is demand-paged, so boot only touches what it needs.
- **Disable fstrim** in the overlay — this is precisely what corrupted the Lyra's card.
- Mount p3 `noatime`; sync on save-state writes.
- Use an A1/A2-rated card from a known brand. The Lyra's failure was a cheap SD04G with corrupted
  block groups; do not repeat that experiment.
- tmpfs overlay for anything under `/etc`, `/var`, `/tmp` that must be writable but not persistent.

Boot cost versus eMMC is roughly +0.5–1 s. Still comfortably inside the target.

## Boot budget — power-on to interactive launcher

Target < 10 s. Realistic on this hardware is **4–6 s**. Rough budget:

| Stage | Budget | Levers |
|---|---|---|
| BROM + SPL (DRAM init) | 0.3 s | fixed |
| U-Boot | 0.3 s | `bootdelay=0`, strip net/USB/env scanning; **falcon mode** removes this stage entirely |
| Kernel decompress + init | 2–3 s | trim the config hard, no modules on the critical path, no initramfs |
| Rootfs mount (squashfs/SD) | 0.5–1 s | squashfs is demand-paged; a fast card matters |
| init + launcher start | 0.5 s | BusyBox init, no getty, no systemd |

The single biggest and most commonly missed lever: **console output**. Every `printk` at 115200
baud is real wall-clock time — a chatty boot can cost several seconds by itself. Ship with
`quiet loglevel=3` and no `console=` on the kernel command line; keep a separate debug bootarg
with `earlycon` for when something breaks. Do not measure boot time with the verbose console on;
the number will be meaningless.

Off the critical path, started after the launcher is up: WiFi/BT firmware load, audio, USB
enumeration, anything network.

Game launch is a **separate** budget (core load + ROM load, ~2–3 s) and is not part of the 10 s.

## Power architecture — one external 5 V supply

Constraints as measured on the actual board:
- `DCIN` on `CON1-P02/P04` is **dead**. That name is literal: it is a power *input* pin, not a 5 V
  output tap. Nothing back-feeds it when the board is powered over micro-USB.
- The panel needs **5 V** (its own USB-C → `VCC_5V` → the 9.6 V `LCD_AVDD` boost and the backlight
  boost) **and 3V3** (from the ribbon).

### USB-5V has two sources

Source: `docs/BPI-M2M-V1_2-20170816-R.pdf`, USB sheet and power sheet.

```
(a) micro-USB in:  USB1 pin1 VBUS ─ USBVBUS ─> D6 (1N5819W, 1A) ─> Q4 (AO3423) ─> USB-5V
                                                                     ^ gate
                                                       R110 100K / R111 1K / Q5 MMBT3904
                                                       base <- USB-DRVVBUS via R112 2K, R113 10K pd

(b) boost:         VCC-3V0 ─> U3 (EN tied to VCC-3V0) ─LX─> L6 (2.2 µH, 2 A) ─> D1 (1N5819W, 1A) ─> USB-5V

USB-5V ─> USB2 (USB-A host) pin 1 VBUS
```

Path (a) alone would make the A port's VBUS software-gated. But path (b) is a boost whose `EN` is
tied straight to `VCC-3V0`, so it runs as soon as the PMIC's 3.0 V rail is up — at power-on, long
before the kernel. The two are diode-OR'd into `USB-5V`.

**So the A-port VBUS is live regardless of DRIVEVBUS**, and there is no enable-timing hazard.
Q4's job is to pass the micro-USB input straight through when it is present, which is more
efficient than boosting from 3.0 V.

> This section has been wrong twice — once claiming the rail was hard-wired, once claiming it was
> gated. Both readings were partial. **Verify with a meter before trusting it** (see below); the
> measurement takes thirty seconds and outranks any amount of schematic archaeology.

### The invariant that actually matters

Whichever source is active, **there is a 1 A Schottky in the path** — `D6` on the micro-USB path,
`D1` on the boost path. That is the hard ceiling for everything downstream, shared with whatever
is plugged into the USB-A port.

And on path (b) it is a 3.0 V → 5 V boost, so ~500 mA out costs ~900 mA+ in on the 3.0 V rail.
Hanging the panel here means micro-USB → PMIC → VCC-3V0 → boost → 5 V → the panel's *own* two
boosts (9.6 V `LCD_AVDD` and backlight): three conversion stages with a 1 A diode in the middle.

Verdict unchanged: acceptable as a convenience tap for bring-up, wrong for the finished build.

### The measurement that settles it

Power the board **with the SD card removed**, so no OS ever runs and DRIVEVBUS is never asserted.
Measure USB-A pin 1 to GND:

- **~5 V** → the always-on boost is feeding it; no timing hazard, tap is safe to use
- **~0 V** → it is gated after all, and the rail is unusable as an always-on 5 V source

### Host communication — currently serial only, and that is not enough

The build as it stands has **no network and no USB gadget**. The only channel is the serial
console on CON3. That is fine for boot debugging but bad for iteration: with SD-only storage and
no ADB, every new launcher or RetroArch binary means pulling the card. The Lyra had ADB over USB;
this board currently has nothing equivalent.

The micro-USB (`USB1`) *is* a real OTG port — `D-`, `D+` and `ID` are all wired to
`USB-DM0`/`USB-DP0`. It only behaves as "power in" because it is plugged into a supply. Into a PC
it gives power **and** data. (`USB3` is a second micro-USB footprint marked `NC\Micro-USB` — not
fitted.)

**ADB is viable, and most of the groundwork is already there.** What the hardware gives is USB
*device/gadget* capability; ADB is a userspace daemon on top of it. The pieces:

| Piece | Status |
|---|---|
| `D+`/`D-` wired to the SoC OTG PHY | yes (schematic, `USB-DM0`/`USB-DP0`) |
| `&usb_otg { dr_mode = "otg"; }`, ID detect on PH8 | already in the upstream board DTS |
| `CONFIG_USB_MUSB_HDRC`, `CONFIG_USB_MUSB_SUNXI`, `CONFIG_USB_GADGET`, `CONFIG_PHY_SUN4I_USB` | **already in `sunxi_defconfig`** |
| `CONFIG_USB_CONFIGFS` + `CONFIG_USB_CONFIGFS_F_FS` (adbd uses functionfs) | **missing** |
| `adbd` in userspace | available as `BR2_PACKAGE_ANDROID_TOOLS_ADBD` |
| configfs setup script to compose the gadget at boot | **to write** |

So it is a config fragment, one package, and a small init script — not a port.

Options, in order of preference:

1. **ADB over the micro-USB.** Matches the Lyra workflow exactly (`adb push`, `adb shell`), and
   the host-side `platform-tools` are already on this machine from that project. Ties up the
   micro-USB, which is free if the board is powered through `ACIN`.
2. **Wi-Fi + SSH.** The AP6212 (BCM43438) is in the upstream DTS. Needs brcmfmac firmware,
   `wpa_supplicant` and dropbear. Slower to set up but robust, and it does not care how the board
   is powered or how Windows feels about USB drivers that day.
3. **`g_ether`/RNDIS + SSH.** Fewer moving parts than adbd, but RNDIS driver support on recent
   Windows is unreliable enough that it is not worth fighting when ADB is available.
4. Re-flashing the SD each iteration. Workable, miserable.

**Plan: add 1 and 2.** They are independent and cheap together; ADB for day-to-day iteration,
Wi-Fi as the channel that keeps working when the USB port is doing something else.

### Why DCIN reads 0 V

`CON1` pins 2/4 (the header's "5 V" pins) are the net **`ACIN`** — the AXP223's AC/charger input.
It is an *input to the PMIC*, not a rail the board drives. Nothing back-feeds it when the board is
powered over micro-USB, which is exactly what was measured.

That makes it useful in the other direction: feeding a clean 5 V **into** `ACIN` on CON1-P02/P04
is a legitimate way to power the board, and avoids pushing the panel's current through the
micro-USB connector.

`ACIN` is also the net on **`CN12`**, the `DC_0507` barrel jack. So if that jack is populated on
this board, powering through it makes `CON1-P02/P04` live — a 5 V tap with **no soldering at all**,
and it frees the micro-USB for a PC data connection. Worth checking the board before reaching for
an iron.

### Instead: one 5 V / 3 A supply feeding both

```
5 V supply ──┬── BPI  (micro-USB, or injected on DCIN CON1-P02/P04 — it is an input, use it as one)
             └── panel USB-C
             common ground, starred back to the BPI board ground
```

Both rails then come up together, there is no probe-ordering hazard, and the USB host port stays
free for the controller. 3V3 for the cable's solder ear comes from `CON1-P01` or `P17`, which is a
real regulated AXP223 output; the panel's 3V3 draw is logic-only and modest.

## RetroArch video driver

**Start with `drm`, not `gl`.**

The Lyra's DRM path (primary-plane scaling, NEON RGB565→XRGB8888, software rotation) is written,
debugged and ports directly — the only piece that doesn't come along is RGA2, which is Rockchip-only.
It also starts faster and uses less RAM than bringing up lima + mesa, and RAM is tight at 512 MB
shared with the GPU.

Mali-400 via lima is a genuine capability upgrade over the Lyra (which had no GPU at all) and is
worth having later for shaders and higher-quality scaling. But it must not be a bring-up
dependency — make it an experiment once the console is working end to end, and measure both.

## What we reuse vs what is new

**Reuse essentially unchanged:** the launcher (`launcher.c`, DRM dumb buffers + SDL2_ttf + evdev),
RetroArch's DRM driver patches, the core set and build scripts, retroarch.cfg, the gamepad
autoconfig.

**Drop:** all RGA2 code (`rga_accel.cpp/h`, the RetroArch RGA2 block) — Rockchip-only. Allwinner's
equivalent is G2D, and with lima available it is probably not worth writing at all.

**New:** Buildroot defconfig for the board, the DSI device tree, a panel driver, and the fast-boot
work the Lyra never got to.

## Critical path

The long pole is **not** RetroArch — that is ported work. It is getting mainline U-Boot + kernel +
Buildroot assembled and a DSI panel lit on a board with no HDMI and no existing mainline
integration. Sequence accordingly:

1. Buildroot defconfig → boots to a serial shell on eMMC
2. DSI device tree + panel driver → `modetest` shows a mode
3. Launcher + RetroArch → console works end to end
4. Fast-boot pass → hit the < 10 s target
5. lima/`gl` evaluation, audio, polish
