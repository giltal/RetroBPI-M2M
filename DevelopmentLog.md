# DevelopmentLog — RetroBPI_M2M

---

## 2026-08-12/13 — Session 1: research, cable verification, first build

### Hardware decisions settled

| Question | Answer |
|---|---|
| SoC variant | **A33** (not R16). No software impact — the upstream DTS is already an A33 tree. |
| Storage | **SD only** — no eMMC populated on this unit, despite the published 8 GB spec. |
| Panel (bring-up) | **EK79007** 7" 1024×600 from the ESP32-P4 kit — 2-lane, plain DSI panel |
| Panel (product) | **Waveshare 5" DSI LCD (B)** 800×480 — 1-lane, TC358762 bridge |
| Base OS | **Buildroot 2026.02.3 LTS**, mainline kernel 6.18.8, U-Boot 2026.01 |
| Power | one external 5 V supply feeding both BPI and panel; DCIN is an input, not a tap |

### Key findings

**Vendor images are a dead end.** Every official BPI-M2M image is kernel 3.4.39 with no
DRM/KMS, so neither the launcher (DRM dumb buffers) nor RetroArch's `drm` driver can run.
Mainline is the only viable base. See `Context.md`.

**sun6i DSI only binds panels, not bridges.** `sun6i_dsi_attach()` does
`of_drm_find_panel(device->dev.of_node)` and nothing else — no `drm_of_find_panel_or_bridge`,
no bridge chain. This single fact drove the panel choice:

- Waveshare 5" (B) → TC358762 **bridge** → will not attach; needs a DSI-native wrapper driver
- Waveshare 7" (C) → `panel-waveshare-dsi` is **I2C-probed** → panel of_node ≠ DSI device of_node
- EK79007 → **plain DSI panel** → attaches natively

**The flex adapter is correct.** Rev F `bpi24-dsi-flex` netlist verified against both the CN2
table and the published RPi DSI pinout. The panel-side order (D1 / CLK / D0 on pins 2-3 / 5-6 /
8-9) looks wrong only if compared against the *CSI* pinout, which is genuinely different. The
ESP32-P4 LCD subboard schematic independently confirms pins 11/12/13 = SCL/SDA/GND — it uses the
identical TE `1-1734248-5` connector and the same assignment.

**The EK79007 subboard is a 3V3 sink and a 5V sink.** No 3V3 regulator anywhere on it
(`U2` = ME6211C18M5G-N 1.8 V LDO, `U3` = AP3012K boost to 9.6 V for `LCD_AVDD`), so `VDD_3V3`
arrives from J3. Its USB-C has 5.1 kΩ Rd on CC1/CC2 — a sink, meant to be fed. Both rails needed.

**`i2c0_pins` = PH2/PH3** in `sun8i-a23-a33.dtsi` — exactly the CN2-13/14 pair the ribbon
carries. So the panel/touch I2C bus is `&i2c0`. `i2c1_pins` = PH4/PH5, matching the vendor
40-pin table's TWI1. Consistent.

**Upstream Buildroot has no retroarch or libretro packages at all.** The Lyra's came from
Rockchip's Buildroot fork. Lifted that whole tree (67 packages) into our BR2_EXTERNAL — and it
turned out to already be the RGA2-free version, since RGA2 was disabled on the Lyra after the
kernel panics. So the RetroArch port is essentially free.

### Work done

**Buildroot external tree** — `buildroot-external/`
- `configs/bpi_m2m_retro_defconfig` — A33/Cortex-A7, NEON-VFPv4, hard float, glibc,
  kernel 6.18.8 (`sunxi` defconfig), U-Boot 2026.01 (`Bananapi_m2m`), ext4 rootfs,
  plus the full bring-up toolkit (modetest, evtest, i2c-tools, strace, usbutils, dtc).
  Modelled on the in-tree `olimex_a33_olinuxino_defconfig` — same SoC.
- `board/bpi-m2m/` — genimage.cfg (sunxi raw SPL at 8 K + rootfs), extlinux.conf,
  kernel config fragment, patch dir.
- `package/retroarch/` — 67 packages lifted from the Lyra SDK, paths rewritten for BR2_EXTERNAL.

Two config fixes were needed: `BR2_PACKAGE_DEVMEM2` has been removed upstream (busybox `devmem`
replaces it), and `BR2_PACKAGE_I2C_TOOLS` depends on `BR2_PACKAGE_BUSYBOX_SHOW_OTHERS`.

**Kernel** — `kernel/`
- `panel-ek79007.c` — new DRM panel driver. 2 lanes, RGB888, seven vendor DCS writes then
  sleep-out (no DISPON — the reference driver sends none), reset 10 ms assert / 20 ms settle.
  APIs verified present in 6.18: `mipi_dsi_dcs_write_seq_multi`, `devm_drm_panel_alloc`,
  `drm_panel_of_backlight`.
- `sun8i-a33-bananapi-m2m-ek79007.dts` — enables `&de`/`&tcon0`/`&dphy`/`&dsi`, panel as a
  child of `&dsi`, GT911 on `&i2c0`, gpio-backlight.
- `scripts/stage_kernel_patches.sh` — generates the Buildroot patches by editing a pristine
  tree and diffing, rather than hand-writing context diffs.

**Launcher** — `launcher/`
- `launcher.c` copied from the Lyra unchanged except panel geometry, which is now
  `-DSCREEN_WIDTH/-DSCREEN_HEIGHT` overridable (was hardcoded 800×480 in ~50 places).
- `gfx_accel.c` — no-op backend replacing RGA2. Every entry point reports unavailable so the
  launcher takes the CPU fallbacks it already had. Those paths were exercised whenever RGA2 init
  failed on the Lyra, so this is well-tested code, not new code.
- **Fixed a real portability bug:** `drm_init()` hardcoded `/dev/dri/card0`. That was safe on the
  RK3506B, which has no GPU, so the display controller was the only DRM device. The A33 has a
  Mali-400 and `sunxi_defconfig` enables lima, which registers its own DRM node with no
  connectors — and probe order against sun4i-drm is not guaranteed. Replaced with
  `drm_open_kms()`, which scans `/dev/dri/card*` and takes the first node that actually has
  connectors and CRTCs. This would have failed on first boot with the panel attached.

### Build results

**Build #1 — PASS** (~33 min, from scratch including the toolchain). Vanilla, no panel work.

```
sdcard.img                   537 MB
zImage                       5,676,832
sun8i-r16-bananapi-m2m.dtb   23,246
u-boot-sunxi-with-spl.bin    595,672
```

**Build #2 — PASS.** Panel driver + DTS + kernel config fragment.
`linux-dirclean` first, so the kernel was re-extracted and the patches genuinely applied rather
than relying on the files staged by hand.

- both patches applied cleanly
- `drivers/gpu/drm/panel/panel-ek79007.o` built, **no warnings**
- `sun8i-a33-bananapi-m2m-ek79007.dtb` (23,707 B) produced
- zImage 5,676,832 → 5,961,184 (+278 KB: DSI encoder, panel, goodix, fbcon)
- fragment verified in the kernel .config: `DRM_SUN6I_DSI`, `DRM_PANEL_EK79007`,
  `TOUCHSCREEN_GOODIX`, `BACKLIGHT_GPIO`, `DRM_FBDEV_EMULATION`, `HID_SONY`, `SQUASHFS` all `=y`

DTB decompiled and spot-checked:
- `dsi@1ca0000` `status="okay"` with `panel@0 { compatible = "fitipower,ek79007"; }`
- `reset-gpios = <&pio 7 6 1>` → PH6, active-low ✓
- `i2c@1c2ac00` (i2c0) okay, `pinctrl-0` set, `touchscreen@5d` present ✓
- `gpio-backlight` on `<&pio 7 1 0>` → PH1, active-high ✓

**Build #3 — two failures, both link-stage, both fixed.**

`launcher.c` itself **compiled clean** on the first attempt (only the pre-existing
`-Wstringop-truncation` / `-Wformat-truncation` warnings inherited from the Lyra source). The
failures were both packaging, not code:

1. `cannot find -ljpeg` / `-lz`. Those were in the Lyra's LDFLAGS because the Rockchip sysroot
   happened to expose them. The launcher asks `IMG_Init` for **PNG only** and never calls jpeg or
   zlib directly, so both were dropped — they resolve transitively via SDL2_image's `DT_NEEDED`.
2. `sdl2_image` only compiles PNG support `ifeq ($(BR2_PACKAGE_LIBPNG),y)`, and the launcher
   hard-fails on `IMG_Init(IMG_INIT_PNG)`. Added `select BR2_PACKAGE_LIBPNG`.

**Buildroot gotcha worth remembering:** selecting libpng does *not* cause an already-built
`sdl2_image` to rebuild, and `SITE_METHOD = local` does not re-sync a changed source dir on a
retry. Both need an explicit `<pkg>-dirclean`. The second failure was exactly this — the retry
rebuilt against the stale Makefile.

**Build #3 — PASS** after the dirclean.

- `sdl2_image` configured with `--enable-png` (confirmed in the configure line)
- `/usr/bin/retrobpi_launcher` — 46,444 B, ARM EABI5 PIE, stripped
- `NEEDED`: libSDL2_ttf, libSDL2_image, libSDL2, libdrm, libfreetype, libm, libc — no jpeg/zlib,
  as intended
- `/usr/share/fonts/launcher.ttf` in place from the overlay

Artifacts exported to `firmware/`: `sdcard.img` (537 MB), `zImage`, both DTBs,
`u-boot-sunxi-with-spl.bin`.

**Build #4 — PASS.** RetroArch smoke test. The point was to prove the lifted package tree (from a
Buildroot 2024.02 fork) still builds on 2026.02. It does, unmodified.

- `/usr/bin/retroarch.bin` — 9,441,240 B, ARM EABI5 PIE, stripped
- `/usr/bin/retroarch` — the Lyra's wrapper (`HOME=/root`, `--verbose` to
  `/tmp/retroarch_verbose.log`). **Disable `--verbose` before shipping**, as on the Lyra.
- `NEEDED`: libasound, libudev, libdrm, libSDL2, libstdc++ — the expected set
- **all four DRM patches applied**, including `0004-drm-gfx-accept-primary-plane-as-fallback`,
  which is the hardware-scaling one the Lyra depended on
- configure line matches the Lyra's: `--enable-plain_drm --enable-neon --enable-floathard`
- `HAVE_DRM=1`, `HAVE_ALSA=1`, `HAVE_UDEV=1`, `HAVE_SDL2=1`; GL/EGL/GBM/KMS all 0, which is
  correct for the plain-DRM path
- cores: `fceumm_libretro.so` (437 KB), `gambatte_libretro.so` (218 KB)
- target rootfs: 49 MB

Note `retro-assets` did not get installed — the `RETRO_ASSETS_INSTALL_TARGET_CMDS` define uses a
relative `cp -r retro-assets` and is only defined when `BR2_PACKAGE_RETROARCH_ASSETS` is *unset*,
which is backwards. Harmless for now (RGUI is built in), but it needs fixing before the menu
assets are wanted.

### Build #5 — host communication (ADB + Wi-Fi)

The first four builds shipped with **serial as the only channel**, which with SD-only storage
means pulling the card for every iteration. The Lyra had ADB over USB; this had nothing.

Prompted by two good catches from the board owner: the micro-USB has `D+`/`D-` routed to the SoC
(so it is a real OTG port, not power-only), and `U3`'s `EN` is tied to `VCC-3V0`.

What was already in place, which made this small:
- `&usb_otg { dr_mode = "otg"; }` with ID detect on PH8 — upstream board DTS
- `CONFIG_USB_MUSB_HDRC`, `USB_MUSB_SUNXI`, `USB_GADGET`, `PHY_SUN4I_USB` — already in
  `sunxi_defconfig`

What had to be added:
- kernel: `CONFIG_USB_CONFIGFS` + `CONFIG_USB_CONFIGFS_F_FS` (adbd uses functionfs)
- kernel: the entire wireless stack — `sunxi_defconfig` carries
  `# CONFIG_WIRELESS is not set` and `# CONFIG_WLAN is not set`. brcmfmac is FullMAC so it needs
  cfg80211 but **not** mac80211, which keeps the addition small.
- `BR2_PACKAGE_ANDROID_TOOLS_ADBD`, `WPA_SUPPLICANT`, `DROPBEAR`
- `S50adbd` — composes the gadget via configfs. Ordering matters: functionfs mounted and adbd
  started *before* binding the UDC, or the host sees an incomplete device.
- `S49wifi` — no-ops unless `/etc/wpa_supplicant.conf` has an `ssid=` line, so an unconfigured
  board still boots at full speed.
- `BR2_TARGET_GENERIC_ROOT_PASSWD="retrobpi"` — dropbear refuses root login on an empty password.
  **Development credential; change it.**

**Firmware gap worth remembering:** Buildroot's `linux-firmware` ships
`brcmfmac43430-sdio.AP6212.txt` (exactly our nvram) but **not** `brcmfmac43430-sdio.bin` for this
chip revision — only the `a0` variant. Upstream that path is a symlink to
`cypress/cyfmac43430-sdio.bin`. Both files are therefore vendored into the rootfs overlay at
`/lib/firmware/brcm/` rather than relying on the package.

**Build #5 — PASS.**

- kernel: `USB_CONFIGFS`, `USB_CONFIGFS_F_FS`, `CFG80211`, `BRCMFMAC`, `BRCMFMAC_SDIO` all `=y`
- target: `/usr/bin/adbd`, `/usr/sbin/dropbear`, `/usr/sbin/wpa_supplicant`,
  `/usr/sbin/wpa_passphrase`, `/usr/sbin/wpa_cli`
- firmware: `/lib/firmware/brcm/brcmfmac43430-sdio.{bin,txt}` (419,798 + 875 B)
- init: `S49wifi`, `S50adbd`, `S50dropbear` installed
- zImage 5,961,184 → 6,370,224 (+400 KB for the wireless stack and gadget layer)

Image exported to `firmware/`.

---

## 2026-08-16/17 — Session 2: first hardware attempt

Build #5 flashed (image contents verified with `debugfs` against `rootfs.ext4` — adbd, dropbear,
wpa_supplicant, launcher, retroarch, both DTBs, firmware all present). Board powers up and
**reboots in a loop**. Owner reports it is not a supply problem, so most likely an exception —
consistent with the `panic=10` in our bootargs, which reboots 10 s after a panic.

### The blocker: there is no serial console on this board as built

Worked out the hard way, in stages:

1. **CON3 is wired to PF2/PF4** — `PF2/SDC0_CLK/UART0_TX` and `PF4/SDC0_D3/UART0_RX`. Those are
   SD-card pins, which is the conflict the vendor docs warn about.
2. **But that is not even the active problem.** Mainline muxes uart0 to `uart0_pb_pins`
   (**PB0/PB1**), and U-Boot does the same through the DT — `Bananapi_m2m_defconfig` does not set
   `CONFIG_UART0_PORT_F`, the option whose help text says PF2/PF4 UART "can be only booted in the
   FEL mode" because it takes over the SD pins. So **nothing in this build drives UART on PF2/PF4
   at all**; CON3 is silent card or no card.
3. **PB0/PB1 reach CON1 P08/P10 only through R104/R105, which are `NC\0R`** — not fitted.

Net result: **no console anywhere.** Mainline A33 offers only three UART pin groups —
`uart0_pf_pins` (PF2/PF4), `uart0_pb_pins` (PB0/PB1) and `uart1_pg_pins` (PG6/PG7, taken by
Bluetooth) — so there is no software route out of this. The two 0 Ω links must be fitted.

Also confirmed no USB-TTL adapter was attached to the dev PC at all (only Intel AMT SOL on COM3),
and no USB gadget enumerating — so ADB was never going to help either. ADB depends on a fully
booted system; serial is the only instrument that sees SPL, U-Boot and early kernel.

### Board layout obtained

Vendor Gerber/assembly RAR downloaded and extracted (Windows `tar.exe` is libarchive-based and
reads RAR v4 — no extra tooling needed). Now in `docs/board_layout/`:
`BPi-M2M-V1_2_assembly_{top,bot}.pdf`, `place_txt.txt`, BOM.

**R104/R105 are on the BOTTOM side** (mirrored flag in the place file; they appear only in the
bot assembly drawing). Coordinates in mils: R104 (-2854.00, -15.50), R105 (-2808.50, -15.50),
both R0402 at 90°, 1.16 mm apart, with CON1 at (-3245.00, 240.00) and the Q4/Q5 USB-switch
cluster nearby as a landmark. Full detail in `docs/wiring.md`.

### FIRST BOOT ACHIEVED

**The console was on CON1 P08/P10 all along.** The board owner spotted it on the CON1 sheet:
PB0/PB1 reach the header through **Q2/Q3 BSN20 level shifters** (`UART2-TX` → `UART2-TX_C`, with
R96/R99 10K pullups to VCC-3V0). `R104`/`R105` are an optional *bypass* around those shifters, not
the only path. My earlier reading — that fitting them was mandatory — was wrong. No rework needed.

Board reached a login prompt at **6.27 s** with a fully verbose console, already inside the
sub-10 s target.

Also proven along the way: with the SD card removed the board enumerates as
`USB\VID_1F3A&PID_EFE8` (Allwinner FEL), which confirmed SoC, PMIC and the micro-USB path were all
healthy while we were still blind.

### Confirmed on hardware

| | |
|---|---|
| Kernel | 6.18.8, cmdline exactly as set in extlinux |
| RAM | 494 MB total, 464 free |
| MMC | `1c0f000.mmc` (SD) + `1c10000.mmc` (SDIO/Wi-Fi) only — **no eMMC**, settled |
| GPU | `lima 1.1.0`, mali400 gp + pp0 + pp1 = **MP2**, 64K L2 |
| UDC | `musb-hdrc.2.auto` present |

**`/dev/dri` = card0 + renderD128, and `[drm] Initialized lima ... on minor 0`.** So **lima owns
card0** and sun4i-drm never registers, because the stock DTB has no display nodes. This validates
the blind fix made to the launcher: the original hardcoded `/dev/dri/card0` would have opened the
GPU node — which has no connectors or CRTCs — and failed. `drm_open_kms()` scanning for a node
with connectors was necessary, not defensive.

### ADB is a dead end on this base

Gadget composition works perfectly — `USB\VID_18D1&PID_4EE7`, product "RetroBPI-M2M", serial
`retrobpi0001`, functionfs mounted, adbd running. But the host parks it at **offline** forever:
Buildroot's `android-tools` is **`4.2.2+git20130218`** — a February 2013 adbd — against host
platform-tools 37.0.0 / adb 1.0.41, which requires the RSA `A_AUTH` handshake it does not speak.

Recommending ADB was a mistake on my part: the Lyra's adbd came from Rockchip's SDK (current),
not Buildroot's ancient Ubuntu snapshot, and I did not check the version before proposing it.
**Use Wi-Fi + SSH instead** — dropbear is already running and the firmware is in place.

---

## 2026-08-17/18 — Session 3: display working, reset isolated to userspace

### The headline: a real mainline bug

**`sun6i_mipi_dsi` cannot send `MIPI_DSI_GENERIC_LONG_WRITE`.** `sun6i_dsi_transfer()`
handles DCS short/long, generic *short* and DCS read, and returns `-EINVAL` for everything else;
`sun6i_dsi_dcs_build_pkt_hdr()` compounds it by only encoding a word count for
`MIPI_DSI_DCS_LONG_WRITE`, treating anything else as a short packet.

That is exactly how the TC358762 bridge is configured — mainline's own `tc358762.c` writes every
register with `mipi_dsi_generic_write()`. So **no TC358762-based panel can work on an Allwinner DSI
host as mainline stands**, which includes the Raspberry Pi 7" touchscreen and all its clones.

Symptom on hardware:
```
panel-waveshare-dsi-b 1ca0000.dsi.0: sending generic data 10 02 03 00 00 00 failed: -22
```

Fixed in `patches/linux/0003-drm-sun4i-sun6i-dsi-support-generic-long-write.patch` — two hunks,
upstreamable. After it: no error, bridge configures, panel lights.

### Panel identified and driven

`i2cdetect` on the ribbon's bus (probe DTB) gave **0x38 + 0x45**, and:

```
i2cget 0x45 0x80 -> 0xc3   REG_ID "ver 2"  => genuine RPi ATTINY map
i2cget 0x45 0x97 -> 0x8b   not 0x46/0x65   => not the newer Waveshare map
```

So mainline `rpi-panel-attiny-regulator` drives power/backlight/reset unmodified. Confirmed on the
running board: `/sys/class/backlight/0-0045` exists and
**`/sys/class/drm/card1-DSI-1/modes` reports `800x480`** — the mode is correct.

`panel-waveshare-dsi-b.c` written: DSI-native `drm_panel` (the only shape `sun6i_dsi_attach()`
accepts), 1 lane, RGB888, `VIDEO|SYNC_PULSE|LPM|HSE`, TC358762 init, plus the vendor's DPI timing
writes (`HTIM1/HTIM2/VTIM1/VTIM2`) that mainline's tc358762 omits.

### Two more bugs found on hardware

**MMC numbering was a coin flip.** Indices are assigned in probe-completion order, so the SD card
raced the SDIO Wi-Fi controller and landed on `mmcblk0` or `mmcblk2` unpredictably;
`root=/dev/mmcblk0p1` then hung forever in `rootwait` with no output. Fixed with DT `aliases`.
Latent since build #1.

**Wi-Fi firmware could never load.** Built-in `brcmfmac` probes at ~1.8 s; the rootfs mounts at
~3.9 s. Fixed by building it as a module. Also added the CLM blob and `wireless-regdb`.

### The remaining problem: reset is in USERSPACE, not power

Hours were spent treating this as a brownout. It is not. Eliminated by substitution:
panel 3V3 on an external AMS1117, board on a 5 V/2 A supply, a dedicated ground wire, USB disabled,
Wi-Fi blacklisted — **all still reset**.

Then the decisive test:

```
init=/bin/sh   ->  SURVIVED 45 s with the panel active
full init      ->  hard reset ~6.6 s, consistently just after udevd starts eudev
```

And stepping through the init scripts by hand from that shell — with `/proc`, `/sys`, `/run`
mounted and the rootfs rw — **every one survived**: `S11modules`, `S40network`, `S49wifi`,
`S50adbd`. So no individual script is the trigger.

Remaining suspect: **udev coldplug** (`udevadm trigger`), which was never exercised in the manual
run. That is the next thing to test.

Also unexplained: the panel cycles through solid colour fields rather than showing the console,
despite the mode reading 800x480. Build #9 (without the DPI timing writes) reportedly showed
readable text at the wrong geometry, so those writes may have regressed it — worth reverting them
as an A/B.

### DISPLAY WORKING (build #12)

The panel locks and renders correctly: console prompt in the right position, correct colours.

**The timing was the last blocker, and the fix was a change of interpretation.** `VP_HTIM/VP_VTIM`
on the TC358762 describe the timing the *panel* needs on its DPI side — not the DSI input timing.
Decoding the Rockchip vendor blob's constants under the TC358764 field layout
(`HBP[24:16]/HSYNC[8:0]`, `HFP[24:16]/HACT[10:0]`, etc.) yields a coherent mode:

```
800x480   hfp=105 hsync=20 hbp=26   vfp=7 vsync=2 vbp=21
htotal=951  vtotal=510   60 Hz @ 29.101 MHz
```

That is **not** `ws_800_480` from the Lyra's DTS (978 x 511 @ 30 MHz, hfp 131 / hsync 45 / hbp 2).
That node is what the Rockchip SoC pushed over DSI while the blob separately told the bridge the
panel's real timing; the bridge absorbed the 27 px/line difference. On sun6i it did not.

Two wrong turns on the way, both mine:

- build #10: hardcoded the vendor constants while still sending `ws_800_480` over DSI. 27 px/line
  mismatch -> colour bars offset by ~1/3 screen, wrapping at the right edge, with vertical banding.
- build #11: "corrected" the constants to match `ws_800_480`. Made the bridge emit a timing the
  panel cannot lock to at all -> solid colour cycling.

**Key diagnostic learned:** the white/red/yellow/blue cycling is the panel's built-in *self-test*,
shown when it sees no valid DPI signal — not garbled framebuffer content. So colour cycling means
"no lock", and anything stable means "locking". The board owner spotted this, and it turned a
subjective "looks wrong" into a binary.

Build #12 sets the DSI mode to the panel's real timing and derives `VP_HTIM/VP_VTIM` from it, so
input and output agree — and the derived values come out bit-identical to the vendor's constants,
which is the check that confirms both the layout and the mode.

### ROOT CAUSE OF THE RESET: power, not software

The ~6.6 s reset is a **brownout**. It was never a display bug, a udev bug, or a
kernel bug. Chain of evidence, each step cheap and decisive:

1. **Reproduced on demand.** `/etc/init.d/S10udevd start` from a bare shell reset the
   board instantly. udev coldplug was the suspect and it was right -- but for the wrong
   reason.
2. **Bisected by subsystem.** `udevadm trigger --action=add --subsystem-match=<s>` for
   16 subsystems: all survived except `platform`. Notably `drm`, `graphics` and
   `backlight` all passed, which killed the "backlight inrush" theory.
3. **Bisected by device.** Walking all 58 entries of `/sys/bus/platform/devices/` one at
   a time, with `udevadm settle` between each, survived *everything* -- `display-engine`,
   `1ca0000.dsi`, `1ca1000.d-phy`, `1c0c000.lcd-controller` included. Same devices as
   step 2, different concurrency. So it was never a specific device.
4. **Removed udev entirely.** Just adding CPU load with the panel lit:

   | load | result |
   |---|---|
   | 1 busy loop | survives |
   | 2 busy loops | survives |
   | **3 busy loops** | **hard reset** |

5. **Confirmed by mitigation.** Capping `scaling_max_freq` to 648 MHz and backlight to
   80: four busy loops survive, and the full `udevadm trigger --action=add` -- the exact
   operation that had reset this board every single time -- completes cleanly.
   A software defect does not care what frequency the CPU runs at.

**Why.** The board is powered through the USB VBUS path, which the AXP223 caps:

```
/sys/class/power_supply/axp20x-usb/input_current_limit : 900000   (900 mA)
/sys/class/power_supply/axp20x-usb/voltage_min         : 4400000  (VHOLD 4.4 V)
/sys/class/power_supply/axp22x-ac/online               : 0        (DCIN unused)
```

900 mA x 5 V = 4.5 W for the SoC, SD, Wi-Fi *and* the 5" panel with backlight at 255.
An A33 with several cores at 1.2 GHz exceeds it, the rail sags below the 4.4 V VHOLD
threshold, and the PMIC drops the input. That is why the reset is always silent --
straight to SPL, no oops, no panic. Linux never gets to complain.

**Everything we observed retro-fits this and nothing else:**

| Observation | Explanation |
|---|---|
| udev coldplug kills it | udevd forks a worker per event; 58 platform events at once = multi-core spike |
| `init=/bin/sh` survives forever | single-threaded, near-idle |
| every init script survives when run by hand | sequential, one at a time |
| `probe.dtb` survives full init | no panel, no backlight -- the headroom absorbs the spike |
| reset always at ~6.6-6.8 s | that is simply when coldplug runs |
| silent jump to SPL | AXP223 undervoltage cutoff, not a kernel fault |

Hours went into this as a software fault -- bisecting init scripts, suspecting the DSI
link, suspecting udev rules. The load ramp settles it in three steps and should have
been the *first* experiment, not the last. **When a board resets with no kernel output
at all, measure power before reading code.**

**Fix.** Feed DCIN from a proper 5 V/2 A supply: that uses the AXP's ACIN path instead
of the capped VBUS path. ACIN and VBUS are independent PMIC inputs with internal
arbitration, so the micro-USB can stay connected for ADB. Confirm the switch with
`cat /sys/class/power_supply/axp22x-ac/online` -> `1`.

**Interim workaround (build #13),** so development is not blocked meanwhile:

- `rootfs_overlay/etc/init.d/S05powercap` -- caps CPU max freq (648 MHz) and backlight
  (80) *before* S10udevd, since coldplug is the biggest spike of the boot.
- `rootfs_overlay/etc/default/udevd` -- `UDEVD_ARGS="--children-max=2"`, flattening
  that spike further.
- `extlinux.conf` now boots `sun8i-a33-bananapi-m2m-ws5b.dtb`.

Both are workarounds for the power path and must be relaxed once DCIN is fed -- 648 MHz
will not be enough for RetroArch.

### Build #13 verified live: coldplug fixed, a second window remains

Staged the build #13 changes by hand onto the running card and did a normal full boot
(no `init=/bin/sh`) with the panel active. Two boots, two different outcomes -- both
informative:

**Boot 2: full success.** Reached `retrobpi login:` with the panel attached.
`POWERCAP_APPLIED` ran at ~5.2 s, **udev coldplug at 9.1 s survived**, and network,
adbd, crond and dropbear all started. The ~6.6 s reset that has blocked every full boot
of this project is fixed.

**Boot 1: reset at ~2.2 s**, in a window the fix structurally cannot reach:

```
[ 2.127944] sun6i-mipi-dsi 1ca0000.dsi: Attached device 5inch-dsi-lcd-b
[ 2.136828] ehci-platform 1c1a000.usb: EHCI Host Controller
[ 2.191967] ohci-platform 1c1a400.usb: Generic Platform OHCI controller
[ 2.195548] sun8i-a33-pinctrl: supply vcc-pf not found, usin      <-- cut mid-line
```

Panel + backlight come up at 2.1 s and USB controller bring-up piles on at 2.2 s, but
`S05powercap` is userspace and does not run until ~5.2 s. That leaves ~3 s at full
backlight and unrestricted CPU frequency with no protection. Marginal: failed once,
passed once, same point.

Covering it from userspace is impossible by construction. The options would be trimming
the OPP table in the DTS (applies as soon as cpufreq registers) and lowering the boot
backlight -- but `rpi-panel-attiny-regulator.c:346` hardcodes `bl->props.brightness =
0xff` with no DT override, so that needs a kernel patch. **Neither is worth doing if
DCIN is about to be wired**, which removes both windows at once. Deliberately not done.

Status: the board is reliable enough to develop on, not reliable enough to ship, and
the gap is entirely the 900 mA VBUS ceiling.

### Build #13 flashed and measured

Flashed and verified on hardware. Everything from the image took effect:

| check | value |
|---|---|
| `MAX_FREQ` / `BACKLIGHT` applied | `scaling_max_freq 648000`, `brightness 80` |
| `UDEVD_ARGS` | `--children-max=2` |
| boot DTB | `sun8i-a33-bananapi-m2m-ws5b.dtb` |
| panel | `Attached device 5inch-dsi-lcd-b`, `fb0`, mode `800x480` |
| DRM nodes | `card0` (lima) + `card1` (sun4i-drm) |
| DCIN | `axp22x-ac/online: 0` — still the 900 mA VBUS path |

`card0` = lima with no connectors, `card1` = sun4i-drm. Exactly the case the launcher's old
hardcoded `/dev/dri/card0` would have failed on; `drm_open_kms()` handles it.

**Boot reliability, 5 consecutive reboots:** 4 clean on the first try, 1 needed one retry
(reset in the ~2.2 s window, then booted fine). ~80%, and it self-recovers rather than
looping. Good enough to develop against, not good enough to ship — and the residual is
entirely the early window that userspace cannot reach. **Fixing DCIN should take this to
5/5**; re-run `scratchpad/reliability.ps1` afterwards to confirm rather than assume.

### DCIN wired -- power problem fully resolved

DCIN connected to a proper 5 V supply. The AXP switched to the AC path exactly as
expected, and the micro-USB stayed connected with no conflict -- both inputs report
online simultaneously, which is the whole point of having two:

```
axp22x-ac/online : 1    present: 1
axp20x-usb/online: 1
```

Re-ran the tests that defined the problem, at **full 1.2 GHz and backlight 255** -- the
configuration that previously died at *three* busy loops even after clamping to 648 MHz:

```
SURVIVED_3CORE_FULLSPEED     scaling_cur_freq 1200000
SURVIVED_4CORE_FULLSPEED     scaling_cur_freq 1200000
SUSTAINED_30S_OK
COLDPLUG_SURVIVED_FULLSPEED
```

**Boot reliability: 5/5 clean, up from 4/5.** The ~2.2 s early window closed too, as
predicted -- it was never a separate bug, just the same 900 mA ceiling hit earlier in
the boot by the panel + USB controller bring-up.

That closes the entire reset investigation. Root cause was one number (the AXP223's
900 mA VBUS cap) and the fix was one wire.

### Build #14: stop capping a board that no longer needs it

`S05powercap` is now **conditional on the supply** rather than an unconditional clamp:

- `axp22x-ac/online = 1` (DCIN) -> no cap at all, full 1.2 GHz. RetroArch needs this.
- `axp22x-ac/online = 0` (USB only) -> clamp to 648 MHz / backlight 80, which keeps the
  board usable under load instead of resetting.

This matters because "runs off USB" is a real scenario for this product, and a board
that silently resets under load is much worse than one that runs slower. The script
self-configures, so neither case needs a different image.

`/etc/default/udevd` (`--children-max=2`) **removed**. It was purely a brownout
mitigation, it serialises udev and therefore costs boot time -- which works directly
against the sub-10 s boot target -- and the frequency cap alone was already proven
sufficient on VBUS.

### Touch: patch 0004, polling when there is no interrupt

`edt_ft5x06` has failed to probe since the panel first came up:

```
edt_ft5x06 0-0038: error -EINVAL: request_irq(0) 0x0 edt_ft5x06_ts_isr edt-ft5506
edt_ft5x06 0-0038: Unable to request touchscreen IRQ.
edt_ft5x06 0-0038: probe with driver edt_ft5x06 failed with error -22
```

Read the driver rather than assuming: mainline 6.18.8 `edt-ft5x06.c` has **no polling
support at all**. It calls `devm_request_threaded_irq()` unconditionally, and with
`client->irq == 0` that returns `-EINVAL` and takes the whole probe down. This is not
specific to us -- the 15-pin RPi DSI connector has no touch-interrupt pin, so *no* cable
can supply one, and every RPi-style DSI panel clone hits this.

`0004-input-edt-ft5x06-support-polling-when-no-irq.patch`:

- adds `edt_ft5x06_ts_poll()`, which just calls the existing ISR body, plus the
  `input_set_drvdata()` the driver never set (it had no reason to before)
- probe now branches: request an IRQ when `client->irq > 0`, otherwise
  `input_setup_polling()` at 17 ms (~60 Hz)
- guards the `enable_irq()`/`disable_irq()` calls in the factory-mode and suspend/resume
  paths so they are never issued against irq 0. Those paths are M06-only and unreachable
  for our FT5506, but `disable_irq(0)` is a latent bug worth not shipping.

**Two process notes, both hard-won:**

1. The patch is generated by **line-number splicing**, not exact-match replacement.
   Exact-match kept reporting zero occurrences of a block that provably matched
   character-for-character.
2. Root cause of that, and of a first broken patch: **heredocs here eat one level of
   backslash escaping.** A `
` meant as two characters inside a C string literal became
   a real line break, producing uncompilable C:

   ```c
   dev_err(&client->dev, "Unable to request touchscreen IRQ.
   ");
   ```

   The same collapse made the search patterns contain real newlines where the source has
   two-character escapes -- hence "no match". Fix: build such strings with `chr(92)` and
   never type a backslash. Now recorded in CLAUDE.md.

Caught only because the generated patch was read before building. Worth continuing to do.

### ADB is a dead end; USB-Ethernet + SSH instead (builds #16, #17)

Investigated ADB properly rather than repeating my earlier guess. **My "old adbd can't
do the RSA auth handshake" explanation was wrong** -- Buildroot's build already disables
auth outright:

```c
//property_get("ro.adb.secure", value, "0");
auth_enabled = 0;//!strcmp(value, "1");
```

and the CNXN handler takes the no-auth path. The real incompatibility is the protocol
itself. Observed behaviour with adb 1.0.41 (v34) against android-tools 4.2.2 (2013):

| operation | result |
|---|---|
| `adb devices`, fresh connection | `device` -- genuinely online |
| `adb shell` | hangs indefinitely |
| anything afterwards | `offline` until adbd restarts |

Modern adb negotiates feature sets and uses shell-v2; the 2013 daemon implements
neither and wedges instead of declining. Not configurable around. Buildroot has no
newer android-tools, so ADB is abandoned as the iteration channel.

**Replacement: USB-Ethernet adapter on a host port, then ssh/scp.** Better tooling than
`adb push` anyway (scp, rsync, port forwarding), and dropbear was already in the image.

Two things the pre-flight check caught, both of which would have wasted the board
owner's time:

1. **No USB-Ethernet drivers were enabled at all.** `CONFIG_USB_USBNET` was not set --
   only the `USB_NET_DRIVERS` menu symbol. Any adapter would simply not have appeared.
   Enabled the common set built-in (CDC/NCM, ASIX 8817x + 88179, SMSC95xx, RTL8152,
   RTL8150) so the chipset does not matter. Built in rather than modules: unlike
   brcmfmac these need no firmware, so there is no rootfs-timing trap.
2. **`BR2_SYSTEM_DHCP="eth0"` silently did nothing.** `/etc/network/interfaces` still
   had only loopback. Buildroot generates that file when the skeleton package builds,
   and target/ is incremental, so the old file survived -- the *same* stale-target trap
   that kept `etc/default/udevd` alive in build #14. Now shipped from the rootfs overlay,
   which is copied at target-finalize every time and therefore always wins.

That trap has now bitten twice. **Rule: when removing or changing a generated file in
target/, verify it in the built image -- do not assume a rebuild refreshes it.** Every
build script here now asserts on the built artifact rather than the source.

Boot-time debt noted deliberately: `auto eth0 / iface eth0 inet dhcp` is blocking, so a
missing cable costs a DHCP timeout. Fine for bring-up, but the fast-boot pass must move
it to a backgrounded or hotplug-driven udhcpc.

Build #17 is cumulative: conditional powercap (#14b), touch polling (#15), USB ethernet
(#16), eth0 config (#17). Verified in the built image: eth0 stanza, USB net drivers,
RTL8152, `input_setup_polling`, `AC_ONLINE`, ws5b DTB, dropbear+scp. Dropbear runs with
`-R` only -- no `-w` -- so root password login works.

### Build #17 on hardware: touch, network and SSH all verified

Flashed #17 with the USB-Ethernet adapter attached. Everything came up.

**Power** -- the conditional cap did its job with no intervention:
`axp22x-ac/online = 1`, `scaling_max_freq = 1200000`. Full speed on DCIN.

**USB-Ethernet** -- the adapter is an RTL8153b:

```
r8152 1-1:1.0 eth0: v1.12.13
r8152 1-1:1.0 eth0: carrier on
inet 10.100.102.76/24   default via 10.100.102.1
```

Non-fatal: `Direct firmware load for rtl_nic/rtl8153b-2.fw failed (-2)`. That blob is an
optional errata/performance patch, not required -- carrier and DHCP both work without it.
Add it to the overlay only if throughput disappoints.

**Touch works.** The `-22` probe failure is gone and the device reports proper geometry:

```
Input device name: "generic ft5x06 (00)"
  BTN_TOUCH
  ABS_X  0..799     ABS_Y  0..479      (matches the panel exactly)
  ABS_MT_SLOT 0..9                     (10-point multitouch)
```

407 events captured from a drag, tracking cleanly with SYN_REPORT per sample:

```
X: 613 -> 587 -> 562 -> 532 -> 513 -> 491 -> 465 -> 439
Y: 265 -> 264 -> 266 -> 270 -> 272 -> 276 -> 281 -> 286
```

**Measured sample interval is ~30 ms (~33 Hz), not the 17 ms configured.** Explanation,
verified rather than assumed: `CONFIG_HZ=100`, so a jiffy is 10 ms and
`input_set_poll_interval(17)` quantises up to 2 jiffies = 20 ms; the ~63-byte I2C read of
the touch data block accounts for the rest. Left as-is -- 33 Hz is smooth for menus and
touch is secondary to physical controls on this device. Dropping
`EDT_FT5X06_POLL_INTERVAL_MS` to 10 would give ~50 Hz at the cost of more I2C/CPU.

**SSH dev loop is live.** Key at `~/.ssh/retrobpi_ed25519`, public half installed to
`/root/.ssh/authorized_keys` over serial (deliberately NOT baked into the image -- an
image with a login key in it should not be casually shareable). Passwordless shell and
file copy both confirmed.

Two gotchas for this loop:

- `scp` needs **`-O`**. Modern OpenSSH scp speaks SFTP by default and dropbear has no
  `/usr/libexec/sftp-server`; without `-O` it fails with "Connection closed".
- Reflashing regenerates dropbear's host keys, so ssh will report REMOTE HOST
  IDENTIFICATION HAS CHANGED. Expected after a flash -- clear with
  `ssh-keygen -R <ip>`. Worth *not* getting numb to: it is the same warning a real MITM
  would produce.

busybox here has no `timeout`, so long-running captures need `setsid ... &` + `killall`.

Full stack now working: display, touch, power, networking, remote shell.

### Builds #18-#20: RetroArch, two-partition card, launcher on the panel

**#18 - RetroArch renders (patch 0005).** RetroArch started but died with "Cannot open
video driver". Two causes, found by reading the build config rather than guessing:

- It was built with `HAVE_PLAIN_DRM=1` but `HAVE_OPENGL/EGL/OPENGLES=0`, and there is no
  Mesa on the target at all. Its compiled-in default driver is `gl`, which cannot open --
  and RetroArch exits rather than falling back. Config now sets `video_driver = "drm"`.
- Then `drmModeGetResources failed`: `gfx/drivers/drm_gfx.c` hardcoded
  `open("/dev/dri/card0")`. On the A33 card0 is **lima** -- render-only, no CRTCs, no
  connectors. Exactly the bug already fixed in our launcher. The Lyra never hit it
  because the RK3506B has no GPU, so card0 *was* the display.

`0005-drm-gfx-open-the-drm-node-that-has-a-display.patch` scans `/dev/dri/card*` and
takes the first node reporting both CRTCs and connectors. Result on hardware:

```
DRM: using /dev/dri/card1
DRM: Init successful.
DRM: primary mode: src 256x192 -> dst 640x480 at (80,0) on 800x480
```

**No GPU acceleration at all.** Worth stating plainly: with no Mesa, every frame is
scaled and blitted on the CPU into a DRM dumb buffer. Fine for fceumm/gambatte at
800x480; it will matter for heavier cores, shaders or smooth scaling. Adding mesa3d with
the lima Gallium driver is the fix when that day comes.

**#19 - two-partition SD card.** `board/bpi-m2m/post-image.sh` builds a FAT32 image and
pre-creates one folder per system plus `_system` and a README, then genimage assembles:

```
p1   512M  ext4   rootfs + /boot
p2   2G    FAT32  label RETROROMS -> /opt/roms   (partition type 0x0c, LBA)
```

The launcher hardcodes `/opt/roms`, so that is the mount point. Pre-creating the folders
means the card is usable from Windows the moment it is flashed, without booting first.
`sdcard.img` grows 538 MB -> 2.68 GB as a result; `ROMS_SIZE_MB` in post-image.sh is the
one knob. Verified on hardware: partition mounts, Windows reads and writes it.

**#20 - launcher was rendering at the wrong size.** It ran, found card1 correctly and was
up in 297 ms, but logged:

```
DRM: mode 800x480 @ CRTC 49
DRM: initialized, double-buffered 1024x600 XRGB8888
```

`launcher.c` defaults to 800x480 and the Kconfig defaults are 800/480 -- but the
**defconfig explicitly overrode them** with `PANEL_W=1024 / PANEL_H=600`, left over from
the EK79007 bring-up panel. Fixed, plus the banner that still announced "RK3506B Lyra
Zero W". Note `SITE_METHOD=local` does not re-sync changed sources, so the launcher needs
an explicit `-dirclean` -- the same Buildroot trap as sdl2_image in build #3.

### The single USB host port is a hard constraint

The board has one USB host port and it is currently the dev link (USB-Ethernet). With a
**hub + PS3 controller** attached the board would not boot at all -- serial completely
silent, not even the U-Boot SPL banner, which rules out software: the SoC never ran.
Unplugging the hub restored booting immediately.

A DualShock 3 charges whenever it is plugged in (~500 mA) on top of the Ethernet adapter
(~200 mA), all drawn through that one port. **A powered hub is required**, not optional.

Controller support itself is already in place -- verified in the kernel config, not
assumed: `HID_SONY=y`, `SONY_FF=y`, `USB_HID=y`, `HID_GENERIC=y`, `INPUT_EVDEV=y`
(what the launcher scans), `INPUT_JOYDEV=y` (for RetroArch). The launcher identifies pads
by `BTN_GAMEPAD` (0x130) with a `BTN_JOYSTICK` fallback, which is how hid-sony presents a
DS3 over USB. Bluetooth DS3 would additionally need the sixaxis pairing step and BlueZ,
neither of which is in the image.

For the product this wants solving properly: Bluetooth pad (the AP6212 has BT, and there
is a bluetooth node on UART1) or GPIO buttons like the Lyra. GPIO fits a handheld best.

### Audio: speaker breakout details (not yet implemented)

Board owner supplied the speaker breakout schematic. Two facts that matter:

- **`SN2010BIF09E`** mono class-D amp fed from `HPL`/`HPR` through `C102`/`C104` and 100 K
  resistors, output to the 2-pin `SPK2` header. So audio comes off the codec's headphone
  outputs, not a dedicated line out.
- **The amp is off by default.** `SDB` ties to `PA-SHDN` with `R107` 100 K to **ground**,
  so it stays shut down unless something actively drives `PA-SHDN` high. That GPIO needs
  identifying on the main board schematic and asserting from the DTS.

Combined with `ALSA device list: No soundcards found` (the sun8i codec is not enabled in
our DTS), audio needs: codec node enabled, plus PA-SHDN driven. RetroArch currently runs
with `audio_driver = "null"`.

### Black screen in games: retroarch patch 0006

Symptom: RGUI menu displayed fine, but launching any game gave a black screen, from the
launcher *and* standalone.

Ruled out first, each with evidence rather than reasoning:

- **Not the launcher.** Identical behaviour running RetroArch standalone; it tears down
  DRM properly before forking (`drm_cleanup()`).
- **Not the pixel format.** All four planes advertise `RG16`, and `modetest` holding
  plane 45 for 15 s in *both* RG16 and XR24 displayed a pattern. (First attempt at this
  test was invalid -- backgrounding modetest with `< /dev/null` gives instant EOF, so it
  set the plane and exited, showing a flash. Same stdin-EOF trap as earlier in the
  project; modetest must run in the foreground to hold.)
- **Not `failed to set CRTC for primary plane`** in isolation -- that error appears in
  the working menu case too.

**The proof** came from inspecting plane state while RetroArch ran:

```
CRTC 49   fb 54
Plane 33 (primary)  crtc 49  fb 54
Plane 45 (overlay)  crtc 0   fb 0     <- RetroArch claims to be using this
```

Plane 45 was never attached. The only thing on screen was the primary plane showing
RetroArch's dummy buffer, which scans out black.

**Root cause** -- a bug in the Lyra's patch 0004. The plane-selection loop does:

```c
if (ptype == DRM_PLANE_TYPE_PRIMARY)
    drm.use_primary = true;      /* set when a primary plane is SEEN ... */
...
drm.plane_id = plane->plane_id;  /* ... never cleared, and no break */
```

Iterating 33 (primary) -> 37 -> 41 -> 45 (overlays) ends with `plane_id = 45` but
`use_primary` still true. That routes the code to `drmModeSetCrtc()`, which **cannot
scale** and requires the fb to cover the whole CRTC -- so a 160x144 core on an 800x480
mode is rejected with EINVAL, and the overlay path that does the scaling never runs.
Any core whose resolution differs from the panel is therefore black; RGUI escapes it by
rendering at full mode size.

The file's own comment says it: *"primary planes can't be scaled: we need overlays for
that."* And the pre-detect block in `drm_get_resources()` already sets `use_primary`
correctly (only when no overlay exists) -- the loop was clobbering it.

`0006-drm-gfx-prefer-an-overlay-plane-and-track-its-type.patch` classifies planes during
the loop and decides afterwards: prefer an overlay, fall back to primary only when no
usable overlay exists, and keep `use_primary` consistent with the plane actually chosen.
Also frees the drmModePlane on every path; the original leaked it on each `continue`.

Generator note: the first attempt inserted the new declarations into the **wrong
function** -- there are two loops over `count_planes` in the file and the search matched
the first. Caught by reading the generated patch before building. Fixed by anchoring on
the cursor-plane comment and walking backwards to its `for()`. Reading generated patches
before building has now caught two defects that would otherwise have been build failures
or silent misbehaviour.

Built in #21; awaiting hardware verification (the PS3 pad occupies the single USB port,
so the board has no network to receive the binary).

### Games render: patch 0006 revised (sun4i overlays cannot scale)

**Correction to the entry above.** The first version of 0006 preferred an *overlay*
plane, on the reasoning that overlays scale and primary planes do not -- which is what
the RetroArch source comment says, and is true on most SoCs. On the Allwinner display
engine it is false, and the patch did not fix the black screen.

Measured directly with modetest, holding the plane in the foreground:

```
-P 37@49:800x480@RG16       -> testing 800x480@RG16 overlay plane 37    (works)
-P 37@49:320x240*2.0@RG16   -> failed to enable plane: Invalid argument
```

**sun4i overlay planes reject any scaled drmModeSetPlane with EINVAL.** Worse, when
RetroArch made the same call it returned *success* while leaving the plane detached --
`modetest` showed `crtc 0, fb 0` for the very plane RetroArch reported using. The
absence of any error in the log, and any complaint in dmesg, is what made this slow to
find: every ioctl claimed to succeed.

Since a libretro core almost never matches the panel mode, the overlay path cannot carry
game video on this hardware at all. The path that *does* work is the one the RGUI menu
was already using: **primary plane, full-screen XRGB8888 buffer, scaled in software** by
`drm_surface_update()`.

Revised 0006 (`0006-drm-gfx-use-primary-plane-sun4i-overlays-cannot-scale.patch`):

- classify planes during the selection loop instead of clobbering `use_primary`
- select the **primary** plane, falling back to an overlay only if there is no primary
- force `use_primary` in the `drm_get_resources()` pre-detect too, so the two agree --
  `drm_surface_setup()` runs *before* plane selection and sizes the framebuffer from
  that flag, so a disagreement allocates a buffer the chosen path cannot use
- free the drmModePlane on every path (the original leaked on each `continue`)

Result on hardware (build #22):

```
[INFO] DRM: using plane/overlay ID 33          <- the primary plane
[INFO] [DRM]: primary/CRTC mode: src 160x144 -> 800x480
Plane 33   crtc 49   fb 53                     <- actually bound
```

**Confirmed by the board owner: the game renders and runs.**

Cost: every frame is scaled and blitted by the CPU. Acceptable here -- there is no Mesa
on the target either, so nothing was GPU-accelerated regardless -- but it is the single
biggest argument for adding mesa3d/lima later.

A note on process: I wrote a wrong patch first because I trusted the upstream comment
about plane capabilities rather than measuring them. The measurement took one modetest
run. **Check what the hardware actually does before patching around what it is
documented to do.** Reviewing generated patches before building also caught two further
defects in this round -- declarations spliced into the wrong function, and a
selection loop that contradicted the pre-detect it was supposed to agree with.

### Full stack working

Display, touch, power, USB-Ethernet, SSH/scp, two-partition card with ROMs on FAT32,
PS3 controller, launcher UI, and RetroArch running games -- all verified on hardware.
Build #22 also autostarts the launcher via `S99launcher`.

### Launcher autostarts (verified), build #23

`S99launcher` verified on hardware -- installed over SSH and rebooted rather than
reflashing, because flashing replaces the FAT32 partition and would have destroyed the
board owner's 156 NES + 24 Game Boy ROMs. The image ships an empty `roms.vfat`, so
**any reflash wipes user content** -- worth remembering now that pushing a 9 MB binary
over scp takes seconds against a 2.5 GB flash.

```
Starting retrobpi_launcher: OK
216 root  /usr/bin/retrobpi_launcher      pidfile 216
Plane 33  crtc 49  fb 55                  <- bound and drawing
STARTUP: ready in 365 ms
```

`RECENT: loaded 1 recents` on that boot is an incidental but useful confirmation: the
previous game launch persisted to `/opt/roms/_system/` on the FAT32 partition and was
read back after reboot, so the writable-data path works end to end.

**Defect found in my own init script.** `/var/log/retrobpi_launcher.log` was empty:
busybox `start-stop-daemon --background` points the child's stdio at `/dev/null`, so
`>> "$LOGFILE"` on the start-stop-daemon invocation captured nothing. The script's own
comment claimed that log was worth having after a failed boot, so it needed to actually
work. Fixed with:

```sh
start-stop-daemon --start --background --make-pidfile --pidfile "$PIDFILE"     --startas /bin/sh -- -c "exec '$DAEMON_PATH' >> '$LOGFILE' 2>&1"
```

Verified capturing the full launcher output. Shipped in build #23.

### Bluetooth for a wireless DS3: stack up, pairing not achieved (builds #24-#28)

Goal: free the single USB host port by putting the DualShock 3 on Bluetooth.
**Not achieved.** The stack is up and every prerequisite is in place, but BlueZ's
sixaxis plugin never acts on the pad. Recording what works, what was ruled out, and
where it stopped, because most of this is reusable.

**Terminology correction:** a DS3 is *not* BLE. It is Bluetooth 2.0+EDR HID over L2CAP,
and it cannot be paired conventionally -- the host's BD address must be written into the
pad over USB, which is exactly what BlueZ's sixaxis plugin does.

**Working:**

- `CONFIG_BT` + BR/EDR + HIDP + HCIUART_BCM; the DTS already had the node as a serdev
  child of uart1 (`brcm,bcm43438-bt`), which is why a stray "Failed to create device
  link ... /soc/serial@1c28400/bluetooth" had been in dmesg since day one
- `hci0` present, chip identified: `BCM43430A1 (001.002.009)`
- dbus + bluetoothd running, adapter **powered automatically** (`AutoEnable`), reported
  as `[default]`, BR/EDR + LE + secure-conn
- sixaxis plugin genuinely compiled in and loaded (`plugins/sixaxis.c:sixaxis_init()`)
- `BCM43430A1.hcd` shipped via `brcmfmac_sdio-firmware-rpi`
- **`CONFIG_HIDRAW=y`** -- a real missing dependency, found and fixed: the plugin talks to
  the pad through `/dev/hidraw*`, and HID_SONY/USB_HID are enough to *use* a pad but not
  to *configure* one. `/dev/hidraw0` now appears when the pad is attached.

**The patchram problem (unresolved).** Built in, `hci_bcm` binds at ~2.3 s, before the
rootfs is mounted, so the .hcd is never found and the chip runs ROM firmware. As a module
(build #25) the patch loads correctly -- and then the chip stops responding:

```
Bluetooth: hci0: BCM43430A1 'brcm/BCM43430A1.hcd' Patch
Bluetooth: hci0: command 0x0c03 tx timeout
Bluetooth: hci0: BCM: Reset failed (-110)
```

Reproducible on a clean module reload, so not a race. Ruled out: flow control is
correctly configured (`uart-has-rtscts` + `uart1_cts_rts_pg_pins`). Remaining suspects:
the 32 kHz LPO clock not physically reaching the chip, or a post-patch baud quirk.
Settled on built-in, because there the adapter at least works.

**The address.** Unpatched, the chip reports `AA:AA:AA:AA:AA:AA` -- which is literally
`BDADDR_BCM43430A1` hardcoded in `btbcm.c`, so btbcm sets `HCI_QUIRK_INVALID_BDADDR`.
Adding `local-bd-address` to the DTS did **not** help: the kernel only honours that
property when the driver sets `HCI_QUIRK_USE_BDADDR_PROPERTY`, and btbcm sets
`INVALID_BDADDR` instead, delegating to userspace. `btmgmt`, which would set it, is not
among the tools Buildroot builds (only bluetoothctl, bluemoon, btattach).

**Where it stops.** With the pad plugged in via USB:

| checked | result |
|---|---|
| `/dev/hidraw0` | present |
| parent HID properties | `HID_ID=0003:0000054C:00000268`, `HID_NAME=PS3 Controller`, `HID_UNIQ=a0:5a:5e:9d:2c:1d` |
| udev broadcasting on the processed group | **yes** -- `UDEV [..] add .../hidraw/hidraw0 (hidraw)` |
| adapter is default and powered | yes |
| sixaxis reaction in `bluetoothd -d` | **nothing** |

Everything the plugin needs is present and the events reach the group it monitors, yet
`device_added()` never logs. Most likely remaining cause is the `INVALID_BDADDR` quirk
making BlueZ treat the adapter as unconfigured (note `Pairable: no`), which would need a
btbcm patch to fix properly -- at which point a powered USB hub is a far cheaper answer
for the same outcome.

**Also worth recording: I broke the build once and nearly shipped it.** Editing the
kernel fragment to revert BT_HCIUART to built-in, my replacement range swallowed
`CONFIG_BT`, `BT_BREDR`, `BT_RFCOMM`, `BT_HIDP` and `BT_LE` as well, so build #26 quietly
produced a kernel with no Bluetooth at all. Caught only because the zImage shrank by
265 KB. Build #27 onward asserts on `CONFIG_BT` and fails the build if it is missing.
**When replacing a block of config, check what else was inside it.**

### Wireless DualShock 3 WORKING -- and the lesson that got it there

`js0` over Bluetooth, USB port free:

```
N: Name="Sony PLAYSTATION(R)3 Controller"
P: Phys=aa:aa:aa:aa:aa:aa
H: Handlers=js0 event3
profiles/input/device.c:uhid_send_input_report() HID report (49 bytes)   [streaming]
```

**The board owner was right to push back.** I had concluded "the stack is up but pairing
does not work, use a powered hub". That was wrong, and the reason it was wrong is worth
recording: this chip (BCM43430A1, as in the RPi Zero W and RPi 3) and this controller are
both extremely common, so "basic Bluetooth pairing does not work" was never a plausible
conclusion. When a well-trodden path appears broken, the fault is almost certainly local.
Being told to go read sources instead of reasoning from symptoms turned a dead end into a
working feature in one session.

**Four separate faults, each masking the next.** Every one was silent:

1. **`CONFIG_HIDRAW` missing.** The sixaxis plugin reads and writes the pad through
   `/dev/hidraw*`. HID_SONY + USB_HID are enough to *use* a pad, not to *configure* one.
   Symptom: plugin loads, then does nothing.
2. **Clone controller name not in BlueZ's allowlist.** `get_pairing()` in
   `profiles/input/sixaxis.h` matches on vid **and** pid **and** name. Ours reports
   `HID_NAME=PS3 Controller`; the table only had "Sony PLAYSTATION(R)3 Controller" and
   "SHANWAN PS3 GamePad". `get_pairing()` returns NULL and `device_added()` returns
   *before its first log line*, so a healthy stack and a rejected pad look identical.
   Fixed by `board/bpi-m2m/patches/bluez5_utils/0005-*.patch`, alongside the SHANWAN
   entry upstream added for exactly the same reason.
3. **No pairing agent.** sixaxis asks an agent to authorise before writing the host
   address. Headless, there is none: "Authentication attempt without agent". Once one
   was registered it worked -- `agent_auth_cb() remote A0:5A:... old_central BE:5A:...
   new_central AA:AA:...` is the moment the pad was reprogrammed.
4. **`CONFIG_UHID` missing.** BlueZ 5.x creates Bluetooth HID devices through
   `/dev/uhid`, not the in-kernel HIDP path. Without it the pad connects perfectly
   (`Connected: yes`) and no `js0` ever appears. `BT_HIDP` covers a route BlueZ no
   longer takes.
5. **`ClassicBondedOnly=true`.** BlueZ's default since CVE-2023-45866 refuses to connect
   HID unless the device is bonded -- and a DS3 never bonds. Endless
   `bonding_attempt_complete() ... status 0x5` (PIN or Link Key Missing) with the link up
   and nothing to show for it. `Paired: no` is the *correct* end state for a DS3.

**Security trade-off, stated plainly:** `ClassicBondedOnly=false` re-opens
CVE-2023-45866 -- anyone in Bluetooth range can connect as an unauthenticated HID device
and inject input. On a games console that is a nuisance rather than a data risk, and it is
the only way to support a DS3, but it should not be carried into anything more sensitive.
Documented in the shipped `input.conf` rather than left implicit.

**Method note.** Web search gave the last fault (ClassicBondedOnly) in one query; reading
the actual BlueZ source we were running gave faults 2 and 3. Neither was reachable by
reasoning from the symptoms, because all of them fail silently. **Read the source you are
running, and search for the exact log line.**

Still open: the BCM43430A1 patchram, which loads but leaves the chip unresponsive
(`command 0x0c03 tx timeout`). The adapter works on ROM firmware, so it is cosmetic for
now -- the address stays the unprogrammed AA:AA:AA:AA:AA:AA, visible as the pad's `Phys`.
An LKML patch adds a 200 ms warmup before reset in the USB path (`btbcm_setup_apple()`);
the serdev path may want the same.

Persisted in build #31: `etc/bluetooth/input.conf` and `etc/init.d/S41btagent` (the agent
is needed only to cable-pair a NEW pad; paired pads reconnect on the PS button alone).

### Controller mapping done; RetroArch menu flicker DEFERRED

RetroArch had no joypad autoconfig at all (`[Autoconf]: PS3 Controller (1356/616) not
configured`), so the pad worked in the launcher -- which reads evdev directly -- and did
nothing in-game. Added profiles under `usr/share/retroarch/autoconfig/`, plus
`joypad_autoconfig_dir` in retroarch.cfg.

Button indices were **derived, not copied**. RetroArch's udev driver assigns them in
`for (i = BTN_MISC; i < KEY_MAX; i++)` order (`input/drivers_joypad/udev_joypad.c`), so
this pad's own capability list gives: SOUTH=0 EAST=1 NORTH=2 WEST=3 TL=4 TR=5 TL2=6 TR2=7
SELECT=8 START=9 MODE=10 THUMBL=11 THUMBR=12 DPAD U/D/L/R=13/14/15/16. Deliberately did
*not* reuse the Lyra's `a=0 b=1 x=3 y=2` -- those are its GPIO button order, not a DS3's.

Two names are shipped because the same pad reports differently on each transport:
"PS3 Controller" over USB, "Sony PLAYSTATION(R)3 Controller" over Bluetooth.

"X and Y don't respond" turned out to be a UX gap, not a mapping fault: the Lyra uses a
**modifier** scheme that we had not ported. Now in retroarch.cfg:

    input_enable_hotkey_btn = 10 (PS)  + menu_toggle=2, exit=9, save=5, load=4,
    state slot -/+ = 15/16

Confirmed working on hardware: PS + triangle opens the menu.

**DEFERRED -- menu flicker.** With the RetroArch menu open the display flips between menu
and game content continuously. Almost certainly the same root cause as the earlier black
screen: we forced `use_primary` (patch 0006) because sun4i overlay planes cannot scale, so
menu and core video now contend for the *same* primary plane, each re-setting the CRTC on
alternate frames. Before, the menu had the plane to itself. Likely fix is to composite the
menu into the same buffer rather than re-issuing drmModeSetCrtc per surface. Not urgent --
the menu is usable -- but it should be revisited with the plane work.

### Audio working, Mesa/lima built, boot measured -- and a self-inflicted regression

**Audio: one missing symbol.** The board DTS already enabled `&codec`, `&dai` and
`&sound`, and SND_SUN8I_CODEC / _ANALOG / SUN4I_I2S were all built. The sound node is
`compatible = "simple-audio-card"` and **CONFIG_SND_SIMPLE_CARD was not set**, so nothing
bound the card -- "No soundcards found" with no probe attempted. Now:

```
card 0: sun8ia33audio [sun8i-a33-audio], device 0: 1c22c00.dai-sun8i-codec-aif1
Headphone 79% [on],  Headphone Source = DAC
speaker-test: Rate set to 48000Hz, 2 channels -- clean run
```

Separately, **alsa-utils was enabled with no tools selected**, so it installed nothing:
that is why aplay/amixer were absent. Not cosmetic -- the sun8i codec powers up muted at
zero, so amixer is required to get any sound at all. Mixer state saved with `alsactl`.
Still to do: the speaker amp's PA-SHDN GPIO (SN2010BIF09E, SDB pulled low) is unasserted,
so only the headphone path is live.

**Mesa/lima: built, runtime unproven.** DRM_LIMA was already on; the userspace half was
absent entirely. Added mesa3d with the lima Gallium driver + GBM + EGL + GLES. RetroArch
rebuilt and now reports `HAVE_EGL=1 HAVE_OPENGLES=1 HAVE_KMS=1` (all previously 0). Mesa
26 ships a single `libgallium-26.0.1.so` megadriver rather than per-driver `*_dri.so`, so
the absent `/usr/lib/dri/` is expected, not a fault; `lima` and `kmsro` are both inside it
(kmsro matters: lima is render-only and must scan out via sun4i-drm).

**Boot time: measured properly for the first time.**

```
U-Boot SPL -> Starting kernel   4.12 s     <- a third of the total, untouched until now
Starting kernel -> udev         4.32 s
                -> network      5.22 s
                -> launcher     8.01 s
                -> login        8.20 s
```

Biggest kernel-side gaps: 1.88 s before the ext4 r/w remount (early init), 1.01 s waiting
for `eth0: carrier on`. `quiet loglevel=4` alone bought almost nothing (7.99 -> 8.20 s;
noise). The real target is U-Boot: build #35 sets BOOTDELAY 2->1 s and drops U-Boot's USB
and network stacks (we boot from MMC). The binary shrank 595,672 -> 487,640 bytes, which
confirms the fragment took. Deliberately NOT BOOTDELAY=0: interrupting autoboot has been
the recovery path repeatedly here.

### The `quiet` change broke the display -- and why that is the interesting part

Adding `quiet` pulled the whole boot ~1 s earlier, moving the i2c probe from 1.5 s to
0.53 s after power-on. The panel's ATTINY MCU had not finished starting and answered
`0x8b` instead of `0xc3`:

```
rpi_touchscreen_attiny 0-0045: Unknown Atmel firmware revision: 0x8b
mipi-dsi 1ca0000.dsi.0: deferred probe pending: supplier 0-0045 not ready
```

`attiny_i2c_probe()` reads REG_ID **once** and returns `-ENODEV` on an unknown value --
permanent, never retried. And because that MCU supplies power, backlight *and* reset to
the panel, its failure took the entire display with it: connector "disconnected", launcher
`FATAL: DRM init failed`, black screen.

The hardware dependency was always there; a slow boot was hiding it. `0005-regulator-rpi-
panel-attiny-retry-the-id-read.patch` retries for ~1 s. On hardware:

```
rpi_touchscreen_attiny 0-0045: panel MCU ready after 1 retries
sun6i-mipi-dsi 1ca0000.dsi: Attached device 5inch-dsi-lcd-b
DSI-1 connected 108x65     launcher STARTUP: ready in 513 ms
```

**One** retry -- ~50 ms -- which confirms the diagnosis rather than merely masking it.
Worth remembering: **making a boot faster is a change to timing, and timing bugs that were
always latent surface as new failures.**

Two process notes: reviewing the generated patch caught a variable declared in the wrong
function (two `unsigned int data;` declarations in that file, and the search took the
first). And busybox `tar caf x.tar.gz` does NOT compress -- the backup was a plain tar
despite the name, so restoring via `gunzip` gave "invalid magic". The restore script now
sniffs the magic bytes instead of trusting the extension.

### Mesa/lima: built and installed, but NO working GL path yet

Correction to the entry above -- "Mesa/lima built" is not the same as "GPU acceleration
works", and it does not, yet.

RetroArch with `video_driver = "gl"` finds the display correctly and then fails to
allocate:

```
[DRM]: Found 1 connectors. Connector 0 connected: yes. Mode 0: (800x480) 60.000824 Hz
[KMS]: Couldn't create GBM device.
[KMS]: Couldn't find a suitable DRM device.
[Video]: Cannot open video driver.. Exiting..
```

The device topology is right -- `card0 -> lima`, `card1 -> sun4i-drm`,
`renderD128 -> lima` -- so this is Mesa failing to pair the render node with the KMS-only
display node. lima has no display engine, so every GL surface must be allocated through
`kmsro`, and `gbm_create_device()` on the sun4i node is exactly where that pairing
happens.

Evidence: the megadriver contains `lima`, `panfrost`, `etnaviv` and `kmsro`, but **no
display-driver names at all** -- no `sun4i-drm`, no `rockchip`, nothing. Whatever
mechanism Mesa 26 uses to associate a KMS-only display driver with a renderer, our build
has no entry for sun4i.

Not chased further: the plain-DRM path works, the cores we run (fceumm, gambatte) are
comfortable on the CPU at 800x480, and this is open-ended Mesa integration work. Reverted
to `video_driver = "drm"` immediately and confirmed the launcher came back (358 ms).

**Left in place deliberately.** Mesa, EGL/GLES/GBM and the RetroArch GL build stay in the
image: they cost image size but nothing at runtime while video_driver=drm, and they are
the starting point for any future attempt. RetroArch reports HAVE_EGL=1 HAVE_OPENGLES=1
HAVE_KMS=1, so the only missing piece is the kmsro pairing.

Worth trying next time: `MESA_LOADER_DRIVER_OVERRIDE=lima` combined with opening GBM on
the render node, or checking whether Buildroot's mesa3d needs an explicit kmsro/display
driver option that we did not set.

### GL WORKING -- a one-line Mesa build-logic fix

Correction to the entry above, which concluded GL was not achievable. It was, and the
cause was a gap in Mesa's own build gating rather than anything about our hardware.

`src/meson.build`:

```meson
if with_gallium and with_gbm
  if with_glx == 'dri' or with_platform_x11 or with_platform_xcb
    subdir('gallium/targets/dril')
  endif
endif
```

The `dril` target is the only thing that produces the per-display-driver DRI stubs --
`sun4i-drm_dri.so` among them -- and `gbm_create_device()` needs the stub matching the KMS
device it is handed. That inner test only considers GLX and X11. We are headless KMS with
`-Dglx=disabled` and no X11, so dril was never built, `/usr/lib/dri` was empty, and EGL
could not start:

```
[KMS]: Couldn't create GBM device.   [KMS]: Couldn't find a suitable DRM device.
```

Mesa's support for our display was already there --
`dril/meson.build` lists `'sun4i-drm_dri.so'` and `dril_target.c` has
`DEFINE_LOADER_DRM_ENTRYPOINT(sun4i_drm)`. Only the build gate excluded it. The enclosing
condition is already `with_gallium and with_gbm`, so adding `or with_gbm` to the inner
test is the right scope: X11/GLX are sufficient reasons to build dril, not necessary ones.

`patches/mesa3d/0001-build-dril-for-headless-gbm-without-x11.patch`. Result on hardware:

```
[GL]: Found GL context: "kms".
[EGL]: EGL version: 1.5     [EGL]: Current context: 0xf494a8.
[KMS]: New FB: 800x480 (stride: 3200).
[GL]: Version: OpenGL ES 2.0 Mesa 26.0.1.
```

**The Mali-400 is now doing the rendering.** This also removes the reason patch 0006
existed (sun4i overlay planes cannot scale, so plain-DRM had to software-scale into the
primary plane) -- the GL path does not use it, and the RetroArch menu flicker deferred
earlier may well be gone with it. Worth re-testing.

Lesson, again: **read the source you are actually building.** "Mesa says lima is
supported" and "this Mesa build produces the file GBM looks for" are different claims.

### RetroArch audio: config_save_on_exit was eating every fix

Audio init kept failing even with a working card. Three separate causes:

1. **RetroArch rewrites its config on exit.** Every edit -- `audio_driver`,
   `audio_device` -- was reverted on the next run; `audio_driver` kept returning to
   `"null"` and `audio_device` to `""`. `config_save_on_exit = "false"` is what made any
   of it stick, and it explains several earlier "the setting didn't take" moments.
2. **Odd sample rate.** Gambatte asks for 32917.50 Hz after rate control; the codec
   refuses and RetroArch fails audio outright rather than resampling. Pinned
   `audio_out_rate = 48000` (confirmed with speaker-test).
3. **Explicit device.** `audio_device = "hw:0,0"`.

Now genuinely streaming, confirmed from the kernel side rather than the log:

```
/proc/asound/card0/pcm0p/sub0/hw_params: rate 48000, channels 2, S16_LE
[ALSA]: Initialized PLAYBACK device "hw:0,0"   [Audio]: Started synchronous audio driver.
```

Also: **alsa-utils ships no init script**, so the mixer state was not restored at boot and
the codec came up muted every time. Added `S35alsa` plus a captured
`/var/lib/alsa/asound.state` (Headphone ~79%, Headphone Source = DAC, AIF1 Slot 0 Digital
DAC on). One flawed measurement worth noting: probing rates with
`aplay -f S16_LE ... /dev/zero` reported every rate rejected, which was an artifact of the
test, not the codec -- speaker-test showed 32000/44100/48000 all fine.

Build #37 persists all of it.

### Build #37 on hardware: ROMs restored, and the muted `asound.state` I shipped myself

Flashed #37, restored the 185-file ROM backup and the DS3 pairing over SSH. Boot log is clean:
panel MCU ready after 1 retry (0.60 s), DSI attached at 1.21 s, `sun8ia33audio` card present,
`sun4i-drm_dri.so` in place, launcher running, DHCP up.

But `Headphone` came up `0% [off]` despite `S35alsa` reporting `OK`. The cause was mine, and it
is worth writing down because the failure was *silent and self-consistent*:

```
name 'Headphone Playback Volume'   value 0
name 'Headphone Playback Switch'   value.0 false  value.1 false
```

I captured `asound.state` with `alsactl store` **after a reboot had already re-muted the codec**,
so I shipped a muted snapshot. `alsactl restore` then did exactly its job — restoring silence —
and reported success. Every layer was working; the *data* was wrong.

Two fixes, because the state file alone is not enough:

1. Re-captured the state, but this time the capture script **refuses to store** unless it has
   verified `Headphone` is both unmuted and above zero. A capture step that cannot fail is a
   capture step that will eventually store garbage.
2. `S35alsa` no longer trusts `alsactl restore`. It verifies the result, and falls back to
   sane defaults if the codec is still silent. `stop` likewise refuses to overwrite a good
   state file with a muted one — otherwise a shutdown while muted poisons the next boot.

Verified all three paths on hardware: good-state restore, muted-state fallback, and the
no-clobber-on-stop case.

**Lesson:** `OK` from a restore tool means "I applied what I was given", not "the result is
correct". When a component's job is to reproduce captured state, test it by checking the
*outcome*, never the exit status — and make the capture side refuse to record a bad state.

### Measuring the menu flicker instead of eyeballing it

The deferred flicker item needed an objective test, since flicker is temporal and no screenshot
can show it. The right measure is the DRM atomic plane state: the old plain-DRM path alternated
page-flips between a small core-sized framebuffer and a full-size menu framebuffer, and that
alternation *is* the flicker.

In-game sampling under the new GL path is unambiguous:

```
[GL]: Found GL context: "kms".
[GL]: Vendor: Mesa, Renderer: Mali400.
distinct plane states over 30 samples: 1
  format=XR24 | crtc-pos=800x480+0+0 | (all other planes 0x0)
```

One plane, full-screen, constant — hardware GL ES on lima, and no alternation.

Getting the *menu* open without a human proved harder than expected, and two approaches failed
before the right one:

- **`network_cmd_enable`** — the build has `HAVE_NETWORKING = 0`, so `HAVE_NETWORK_CMD = 0`.
  Dead on arrival, and busybox has no `nc` to drive it with anyway.
- **`stdin_cmd_enable`** — compiled in (`HAVE_STDIN_CMD = 1`) but it never initialises. Reading
  `input/input_driver.c` and `command.c`: the udev input driver claims stdin via
  `linux_terminal_grab_stdin`, and `read_stdin()` is a plain **blocking** `read()` with nothing
  anywhere setting `O_NONBLOCK`. I hypothesised RetroArch was frozen on an empty FIFO — and was
  **wrong**: measuring `utime+stime` showed 211 jiffies over 3 s, a perfectly healthy main loop.
  The interface simply never opened.

The honest outcome of that round was "the menu never opened, so the menu measurement is
meaningless" — which is exactly what the test script printed, because it checked whether its own
stimulus had landed before trusting its result. **A test that cannot detect its own no-op is not
a test.**

So: `CONFIG_INPUT_UINPUT=y` plus `tools/inject-input.c`, a small uinput virtual keyboard. Injected
events travel the same evdev/udev path a real gamepad's do, which makes the measurement
representative rather than a special case — and it gives the project permanent automated input
testing for the launcher too.

### MENU FLICKER RESOLVED (was deferred since the controller-mapping session)

Confirmed on hardware by eye: **no flicker in the menu**. That closes the item deferred back
when the user reported "menu opens, it flickers, menu and game display continues to flip".

The fix was not a fix for the flicker at all — it was the GL work. Under the plain-DRM path,
patch `0006` forced core video onto the primary plane, and RetroArch's DRM driver keeps a
*separate* framebuffer for the menu, so with the menu open it alternated page-flips between a
small core-sized buffer and a full-size menu buffer. That alternation was the flicker. The GL
driver composites the menu as a texture over the game inside a single GL surface and does one
`eglSwapBuffers` per frame, so there is only ever one buffer to show. The plane sampling agrees:
one plane, `crtc-pos=800x480+0+0`, constant across 30 samples.

Worth noting what this cost: the flicker was never worth debugging directly. It was a symptom of
running a software-scaled single-plane path on hardware that has a GPU, and it disappeared as a
side effect of using that GPU. **A bug that vanishes when you stop doing the wrong thing was
never really a bug in its own right.**

The uinput injector was built to measure this and arrived after the human answer did — but it
stays, because it is the only way to drive the launcher or RetroArch from a script, and the
next regression of this kind should not need a person watching the panel.

### Verified after a real power cycle (post-#37 kernel push)

```
uptime 16 s                                  <- genuinely a fresh boot
Headphone  Playback 50 [79%] [-13.00dB] [on] <- the ALSA fix holds across a boot
/dev/uinput  crw-------  10, 223             <- uinput live
inject: F1 (code 59)                         <- injector works on target
/opt/roms  156 nes + 24 gb                   <- ROMs mounted
retrobpi_launcher running
```

`inject-input` is now a proper BR2_EXTERNAL package rather than a binary I hand-copied into
`target/` — otherwise the next clean build would have dropped it silently, which is exactly the
incremental-`target/` trap this project has already been bitten by twice.

### In-game audio was broken, and the cause was vsync

"Check the sound" turned out to be a real bug rather than a confirmation. A tone played fine, but
during a game the ALSA stream cycled continuously:

```
t= 0s state=RUNNING   hw_ptr=13624  appl_ptr=16022
t= 2s state=PREPARED  hw_ptr=128    appl_ptr=2407
t= 4s state=RUNNING   hw_ptr=60544  appl_ptr=62518
t= 6s state=PREPARED  hw_ptr=520    appl_ptr=2407
t= 8s state=XRUN      hw_ptr=0      appl_ptr=2406
```

That is an xrun storm: underrun, recover, prepare, restart, repeat. The pointer resetting to zero
is the giveaway — `hw_ptr` counts from stream start, so it only goes backwards on a re-prepare.

Isolating it mattered more than fixing it. A plain `speaker-test` advanced the hardware pointer
194752 frames in 4 s against a real-time figure of 192000 — **the hardware path is exact**. So the
codec, DMA, clocks and mixer were all fine and the fault was entirely RetroArch-side. (Worth
noting: earlier sessions had called `speaker-test` "working" on the basis that it printed no
error. It had never been checked that any frames actually moved. "No error" is not "it worked".)

CPU was not the problem either: 276 of 400 jiffies, i.e. 69% of *one* core out of four.

The measurement that found it — bad samples out of 24, sampling stream state twice a second:

```
latency  64, vsync on : 18/24        latency 192, vsync on : 4/24
latency 128, vsync on :  9/24        latency 128, vsync off: 0/24
```

Bigger buffers only *masked* it; vsync was the jitter source. RetroArch was blocking on the page
flip and only staying ~1900 frames ahead in a 3072-frame buffer, so any hitch drained it.

The fix is `video_vsync = "false"`, and the reason that is safe here is specific to this hardware:
`sun4i` never sets `mode_config.async_page_flip`, and DRM core rejects `DRM_MODE_PAGE_FLIP_ASYNC`
from drivers that do not advertise it (`drm_plane.c:1408`). **Every flip lands on vblank whatever
this setting says** — measured at ~60 flips/s with vsync on *and* off. Turning it off only stops
RetroArch blocking; it cannot introduce tearing. `audio_latency` also went to 128 ms for headroom.

Result, 60-second soak, sampling once a second:

```
fceumm    (47920.27 Hz -> 48000)  0 bad samples of 60
gambatte  (32917.50 Hz -> 48000)  0 bad samples of 60
```

**Lesson:** an audio symptom had a video cause. The buffer-size knob was the obvious lever and it
"helped" at every step, which made it look like the right lever — 18 -> 9 -> 4 bad samples reads
like progress. It was masking. The isolating test (does the hardware move frames on its own?) was
worth more than the whole tuning sweep.

### Boot time: 10.87 s -> ~4.9 s, and one optimisation that had to be thrown away

`rcS` was instrumented to record each init script's duration to `/run/boottiming`; that
instrumentation now ships, because attributing a boot regression by guesswork is hopeless.

Starting point, launcher on screen at **10.87 s**:

```
3.25 s  S01seedrng      1.18 s  S50adbd
1.94 s  S40network      0.74 s  S10udevd
```

The kernel reaches `/sbin/init` at 1.56 s, so essentially all of the fat was in userspace.

- **adbd removed.** ADB never worked (android-tools 4.2.2, 2013) and was documented as a dead end
  sessions ago, yet it still composed a USB gadget on every boot. 1.18 s for nothing.
- **network backgrounded.** `udhcpc -t 3 -T 1` spends up to 3 s in the foreground before forking.
  Nothing needs an IP address to show a menu.
- **seedrng backgrounded** — and this is where the interesting part started.

Removing seedrng entirely, expecting to save 3.25 s, made the boot **slower**: `crng init` slipped
from 3.80 s to 5.66 s and the launcher went to 9.67 s, because udevd, the Bluetooth agent and
dropbear all block until the kernel CRNG is ready. seedrng is not overhead; crediting the saved
seed is what makes the CRNG ready early. It just should not do it on the critical path.

Reading the busybox applet showed it credits the seed *first* and uses `GRND_NONBLOCK` for the new
one — so its cost is the `fsync()` writing next boot's seed to a slow SD card, not entropy. That
suggested splitting the halves: credit synchronously, regenerate in the background. A 60-line
`seed-credit` tool was written to do exactly that, and **it worked**: `crng init` moved from 3.5 s
to 2.1 s, reliably, across every boot.

It made no difference to when the launcher appeared:

```
with seed-credit    : 8.28 / 5.08 / 7.06   mean 6.81 s   crng ~2.1 s
without             : 6.93 / 6.20 / 5.59   mean 6.24 s   crng ~3.5 s
```

Once the CRNG stops being the gate, making it readier buys nothing. The tool was deleted rather
than shipped.

**The lesson is really about measurement discipline.** Every number before this point had been a
single sample. Run-to-run spread on this board is about +/-1.5 s, which is larger than most of the
individual wins being claimed. Two of the earlier "conclusions" in this session were single-run
artefacts. Boot timing on an SD-card-backed system needs repeats, and a change that only looks
good once has not been shown to be good at all.

Last change: the launcher moved from **S99 to S12**. It ran dead last, behind dbus, alsa,
bluetoothd, network, wifi, crond and dropbear, none of which it needs — its real dependencies are
`/dev/dri` and the input devices, both ready once udev has settled. Everything else now finishes
behind a UI that is already on screen.

Final, four consecutive boots: **5.78 / 4.08 / 4.83 / 4.98 — mean 4.92 s** (from 10.87 s).

A `post-build.sh` was added, because renaming the launcher script would otherwise have shipped
*both* copies: Buildroot's `target/` is incremental, so a renamed overlay file leaves its old self
behind. That trap has now bitten this project three times, so the script deletes the known-stale
paths and hard-fails the build if more than one launcher init script survives.

### Speaker amplifier: PA-SHDN identified as PH9, wired as a DAPM aux device

Board owner supplied the main board schematic extract. `PA-SHDN` is on ball **E14 = PH9**.

The row alignment is worth stating because it is the kind of thing that is easy to get wrong by
one row on a cropped schematic, and a wrong GPIO here would drive an unrelated net. The extract
shows four balls E14..E17 against four pins PH9..PH6, and two of those rows are self-checking:
E16 carries `UART3_RX` against the pin labelled `PH7/SPI0_CLK/UART3_RX`, and E17 carries
`UART3_TX` against `PH6/SPI0_CS/UART3_TX`. Those anchor the bottom two rows, so counting up gives
E15 = PH8 = `USB-ID` (plausible on its own -- the OTG ID pin) and **E14 = PH9 = `PA-SHDN`**.

Polarity comes from the speaker breakout schematic recorded earlier: the amp's `SDB` pin has
`R107` 100 K to **ground**, so it is held shut down until something drives `PA-SHDN` high.
Hence `GPIO_ACTIVE_HIGH`. PH9 is referenced nowhere in the board DTS, `sun8i-a33.dtsi` or
`sun8i-a23-a33.dtsi`, so there is no conflict.

It could have been a `regulator-fixed` held permanently on, or a line the launcher pokes at
startup. It is instead a `simple-audio-amplifier` aux device on the sound card, so DAPM powers
the amp up only while a stream is actually running. On a battery handheld that matters twice
over: no permanent current draw, and no amplifier sitting there amplifying the codec's idle
noise into the speaker.

```dts
speaker_amp: audio-amplifier {
	compatible = "simple-audio-amplifier";
	enable-gpios = <&pio 7 9 GPIO_ACTIVE_HIGH>;	/* PH9 = PA-SHDN */
	sound-name-prefix = "Speaker Amp";
};

&sound {
	simple-audio-card,aux-devs = <&codec_analog>, <&speaker_amp>;
	simple-audio-card,widgets = "Speaker", "Speaker";
	simple-audio-card,routing =
		"Left DAC", "DACL",
		"Right DAC", "DACR",
		"Speaker Amp INL", "HP",
		"Speaker Amp INR", "HP",
		"Speaker", "Speaker Amp OUTL",
		"Speaker", "Speaker Amp OUTR";
};
```

Two details that would have been bugs:

- **Overriding a property replaces it.** `sun8i-a33.dtsi` already sets `aux-devs = <&codec_analog>`
  and the two DAC routes. Adding the amplifier without restating those would have dropped
  `codec_analog` and taken the entire analog path -- and therefore all audio -- with it.
- **The A33 analog codec exposes a single `HP` output widget**, not `HPL`/`HPR`
  (`sound/soc/sunxi/sun8i-codec-analog.c`), so both amplifier inputs are fed from `HP`. The amp
  is mono anyway, and the breakout sums `HPL`/`HPR` through `C102`/`C104` into it.

Routing from a codec OUTPUT widget into an amplifier INPUT widget is the established pattern for
this driver rather than something invented here -- `arch/arm/boot/dts/ti/omap/omap3-echo.dts`
does exactly this, and the Rockchip retro handhelds (`rk3566-anbernic-rg353p` and friends) use
the same amplifier binding for the same job.

**Known limitation:** there is no headphone jack detect on this board, so the amp is enabled
whenever playback runs, headphones plugged in or not. Muting the speaker on insertion would need
a detect line the hardware does not bring out.

**Verified on hardware, before the speaker is even soldered.** The whole DAPM chain can be tested
by watching the GPIO, which makes the eventual soldering either work or fail for purely mechanical
reasons:

```
simple-amplifier audio-amplifier: supply VCC not found, using dummy regulator
 0 [sun8ia33audio  ]: simple-card - sun8i-a33-audio     <- card still registers

gpio-233 (   |enable   ) out lo      1. idle
gpio-233 (   |enable   ) out hi      2. during playback   (pcm state: RUNNING)
gpio-233 (   |enable   ) out lo      3. after stop

Speaker Amp DRV:  On  in 4 out 2
Speaker:          On  in 8 out 1
```

The pin identification then got confirmed twice over, independently of reading the schematic:

- The GPIO dump shows `gpio-232 (|usb0_id_det) in hi` immediately followed by
  `gpio-233 (|enable) out lo` -- consecutive lines, one pin apart.
- Mainline's own `sun8i-r16-bananapi-m2m.dts` assigns `usb0_id_det-gpios = <&pio 7 8>` (PH8), and
  the schematic extract puts `USB-ID` on E15, the row directly above `PA-SHDN` on E14.

So mainline's independent knowledge of this board agrees with the row alignment: E15 = PH8 =
USB-ID, therefore E14 = PH9 = PA-SHDN. That is a much stronger check than counting rows on a
cropped image, and it is worth reaching for whenever a schematic reading drives a code change --
find something already known that the same reading must also predict.

The `VCC not found, using dummy regulator` line is expected: the amplifier's supply rail is on the
breakout, not switchable from the SoC, so no `VCC-supply` is declared.

One tooling trap fixed on the way. `scripts/stage_kernel_patches.sh` generates the kernel patches
by editing the extracted tree and diffing it -- so it *finishes with the tree already patched*, and
building from there makes Buildroot try to apply its own patches a second time:

```
The next patch would create the file .../panel-waveshare-dsi-b.c, which already exists!
Reversed (or previously applied) patch detected!  Skipping patch.
make: *** [.stamp_patched] Error 1
```

A second `linux-dirclean` after generating is required. The script now prints that in a closing
banner, and `scripts/build-amp.sh` does it automatically.

### Sound actually works -- two stacked faults, and a correction

The speaker went on and produced nothing. Then, after one fix, "very short ticks". The end state
is working audio, but the route there is worth recording because the first fault was invisible to
every check that had been run up to that point.

**Fault 1: `AIF1 DA0 Playback Volume` was 0, and 0 means MUTE.**

```c
DECLARE_TLV_DB_SCALE(sun8i_codec_vol_scale, -12000, 75, 1)
```

-120 dB, 0.75 dB per step, and the trailing `1` is *mute at minimum*. So index 0 is not "quiet",
it is off, and 0 dB is index 160 of 192. That control sits between the I2S interface and the DAC,
so nothing analog had ever left this board.

Everything else read healthy while it was muted: the DMA advanced at exactly real time, every DAPM
widget said `On`, the amplifier GPIO toggled correctly, and `Headphone` showed 79% unmuted. The
codec registers agreed too -- `0x03` = `0xcc` (DAC analog L/R enabled, both HP mutes released,
source = DAC) and `0x07` = `0x84` (`HPPAEN` set). A single muted stage upstream made all of it
meaningless, and nothing in the system reported a problem.

**This invalidates an earlier claim in this log.** The 60-second soak that reported "0 bad samples"
on both cores was measuring *buffer health on a silent stream*. Frames moving through a DMA engine
says nothing about whether an analog signal exists. The audio work had been described as verified;
it was not.

**Fault 2: level.** With the digital stage unmuted, the analog stage was still at -13 dB, which is
too weak to drive the amplifier through the breakout's 100 K series resistors -- only transients
got through, which is what "ticks" were. At 0 dB analog it is loud and clean.

A dead end worth recording: the ticking looked exactly like phase cancellation, since the breakout
sums HPL and HPR into a mono amp and an identical sine on both channels would null at the summing
node. Four generated WAVs (left only, right only, both in phase, right inverted) all ticked
equally, which killed that theory in one round trip. Generating the test signals was worth more
than reasoning about them -- `speaker-test -s 1` had already produced a misleading result because
it exits after one pass, which showed up as the stream restarting and the frame counter going
backwards.

**Volume control.** `Settings -> Volume` existed but did nothing on this board: it was still the
Lyra's code, driving `cset numid=37` over a 0-510 range. Both are that board's Rockchip codec, and
numid is not stable across kernels anyway. It now addresses `Headphone Playback Volume` by name
over the real 0..63 range, with 0% a true mute. The dial is spread over the top 40 dB rather than
the full 63, because the bottom of the range cannot drive the amplifier -- a dial where half the
travel does nothing is a worse dial.

The gain deliberately lives in the ANALOG stage. The digital controls go to +24 dB and anything
above unity clips, so `S35alsa` pins them at 160 and leaves them there.

`S35alsa`'s fallback had encoded the same bug it was meant to catch -- `sset Headphone 80%` lands
near the -13 dB that ticks. It now sets the analog stage to maximum, on the principle that a
fallback should err loud rather than silent, since the launcher overrides it a second later from
`/opt/roms/_system/state.txt`.

Verified on hardware: fallback recovers a wrecked mixer (`DA0 0,0 -> 160,160`, "defaults applied"),
the launcher applies its saved level at startup (`volume=50` -> index 43 -> -20 dB), and the dial
maps 0/25/50/75/100% to mute/-30/-20/-10/0 dB.

**Lesson.** Every check that passed was checking a stage rather than the path. "The DMA advances",
"the widget is On", "the GPIO is high", "Headphone is 79%" -- all true, all simultaneously
compatible with total silence. For a signal chain, the only meaningful verification is end to end,
and where the end is a human sense, a human has to be asked. The instinct to keep gathering more
proxy measurements was the thing to resist.

### The full core set, and a toolchain gap the fork did not have to face

Expanded from the two-core smoke test to the same 17 cores the Lyra project
ships. That project is also a Cortex-A7, so the emulation side carries over
directly; the toolchain does not. The package tree came from a Buildroot
2024.02 fork built with roughly GCC 8, and this is GCC 14.3.

First pass: **12 of 17 built, 5 failed.** Building them one at a time was the
right call -- Buildroot stops the entire build on the first failure, so a single
`make` would have reported "fbalpha2012 failed" and said nothing about the other
sixteen. A per-core loop collects every failure in one run instead.

Every failure was the C language getting stricter, not a bug in any emulator:

- **`-fno-common` became the default in GCC 10.** These cores rely on tentative
  definitions, so the same global lands in several objects and the link dies:
  `multiple definition of 'config'` (genesisplusgx), `'IAPU'` (snes9x2005),
  `'f_load_sample_sizes'` (mame2003plus), `'fuse_githash'` (fuse).
- **GCC 14 promoted a family of warnings to hard errors.** fbalpha2012 died on
  `assignment to 'const long unsigned int *' from incompatible pointer type
  'const z_crc_t *'` -- a zlib type mismatch that had been a warning for years.

The fix is a shared `LIBRETRO_COMPAT_CFLAGS` in `package/retroarch/retroarch.mk`
(which is included before the per-core `.mk` files, so the variable is visible to
all of them), applied **per core** rather than added to global `TARGET_CFLAGS`.
Going global would silently weaken diagnostics for every other package on the
system, including ones where an implicit declaration really is a bug worth
failing on. Opting in per core also documents, in that core's `.mk`, which
compatibility it needs.

`scripts/add-compat-flags.py` applies it, so the next core that hits this is one
command rather than another round of hand-editing.

Three cores are carried as documented-broken from the Lyra project rather than
silently dropped, so nobody re-enables them expecting them to work: GPSP (ARM JIT
assembler errors), PICODRIVE (submodule host unreachable), BLUEMSX (compile
errors that `-fcommon` does not fix).

### Integration the cores alone would not have given

Adding cores is not the same as making systems appear, and three separate things
had to agree:

- **The launcher's system table pointed GBA at `gpsp_libretro.so`** -- the core
  we deliberately do not build. GBA ROMs would simply never have shown up, with
  no error anywhere, because the launcher hides a system whose core is missing
  (`access(corepath, F_OK)`). Now points at mGBA, which is the better core anyway.
- **`post-image.sh` created folders that had no core** (`psx`, `atari800`) and
  omitted folders for cores we ship (`cps2`, `cps3`, `arcade`, `mame`). A folder
  with no core behind it is worse than no folder: it invites the user to drop
  ROMs somewhere that will never work and never say why.
- **Per-core overrides from the Lyra project were dead weight without a config
  change.** `config/fuse/fuse.cfg` sets libretro device 513 (Sinclair joystick) --
  without it the Spectrum sees no input at all -- and `MAME 2003-Plus.cfg` maps
  the analog stick to the d-pad. RetroArch reads neither unless
  `auto_overrides_enable` is true, and the `.opt` files need
  `global_core_options = "false"`. Copying the files without those settings would
  have looked complete and done nothing.

That last one is the recurring shape of this whole session: an artefact that is
present, plausible, and inert.

### Verified on hardware: 18 cores present, 6 measured running

All 17 Lyra-set cores plus parallel-n64 are installed and their runtime
dependencies resolve on target (`ldd`, 0 unresolved). Building is not the same
as loading, and loading is not the same as running, so all three were checked.

Six cores could be exercised end to end against ROMs already on the card, and
every one holds a full frame rate with audio streaming:

```
NES  1942 (Japan, USA).nes
  fceumm            60 fps   256x224   audio=RUNNING
  nestopia          60 fps   256x224   audio=RUNNING
  quicknes          60 fps   256x224   audio=RUNNING
GB   Alleyway.gb
  gambatte          60 fps   160x144   audio=RUNNING
  mgba              60 fps   160x144   audio=RUNNING
  tgbdual           60 fps   160x144   audio=RUNNING
```

(fps here is counted from the LCD controller's vblank IRQ over 5 s, not from
anything RetroArch reports about itself.)

The other twelve were checked as far as is possible without content: RetroArch
dlopens each one and it reaches `Libretro core requires content, but nothing was
provided` -- which is the *success* path for a content-requiring core, since a
core that failed to load reports `Failed to open libretro core` instead.

Launcher shows `MENU: found 2 systems` and starts in 451 ms; only nes and gb have
ROMs, and hiding empty systems is the intended behaviour.

**What is genuinely unverified, and cannot be from here:** SNES, Genesis, Master
System, Game Gear, PC Engine, SuperGrafx, Atari 2600/7800, ZX Spectrum, Doom,
arcade (FBA/MAME) and N64 all need content to test. Those are cores that build,
load and have their config in place -- nothing more should be claimed for them.

### N64: set up, not yet demonstrated

parallel-n64 builds (2.7 MB core). Nothing about it has been run yet, so this
section records choices and reasoning, not results.

**Why parallel-n64 and not mupen64plus-next.** The Mali-400 MP2 is OpenGL ES 2.0
only -- no GLES3, no desktop GL. mupen64plus-next requires GLES3/GL3 and would
build fine and then fail at runtime, which is the worst of both. parallel-n64
still carries the older GLES2 renderers.

The core's own option list, read out of the built `.so` rather than guessed:

```
CPU Core;                  dynamic_recompiler|cached_interpreter|pure_interpreter
GFX Plugin;                auto|glide64|gln64|rice|angrylion
GFX Accuracy (restart);    veryhigh|high|medium|low
RSP Plugin;                auto|hle|cxd4
Resolution (restart);      640x480|960x720|...|320x240
```

Two of those defaults would have been actively wrong here:

- **`gfxplugin = auto` can select angrylion**, which is a software rasteriser.
  On this SoC that is hopeless, and it would have looked like "N64 is too slow"
  rather than "the wrong renderer was picked". Pinned to `glide64`.
- **`rspplugin = auto`** can land on `cxd4`, the accurate LLE interpreter. Also
  far too slow. Pinned to `hle`.

`cpucore` is set to `dynamic_recompiler` -- the ARM dynarec is present in this
build (`new_dynarec.c`, `Init new dynarec` are both in the binary), and the
interpreters would be pointless without it.

The options file has to live at `config/ParaLLEl N64/ParaLLEl N64.opt`, and that
exact string was taken from the binary too. A wrong directory name here produces
no error -- RetroArch just uses defaults -- which is the same silent-inert
failure mode as the per-core overrides above.

**Expectation setting:** a 1.2 GHz Cortex-A7 with a Mali-400 is well below what
N64 emulation normally wants. The Lyra project listed N64 as untested
(`P2-4.6 - Test PS1/N64 feasibility`) and never got to it. Some titles may run;
many will not. The value here is that it is now set up to be *measured* rather
than speculated about.

### Full ROM set on hardware: 15 systems, and two corrections

With ROMs loaded for every system, all of it measured. Frame rate is counted
from the LCD controller's vblank IRQ, not from anything RetroArch claims:

```
nes           fceumm          59 fps   256x224   audio=RUNNING
snes          snes9x2005      60 fps   256x224   audio=RUNNING
gb            gambatte        60 fps   160x144   audio=RUNNING
gbc           gambatte        60 fps   160x144   audio=RUNNING
gba           gpsp            60 fps   240x160   audio=RUNNING
genesis       genesisplusgx   60 fps   256x192   audio=RUNNING
mastersystem  genesisplusgx   60 fps   256x192   audio=RUNNING
atari2600     stella2023      59 fps   320x228   audio=RUNNING
atari7800     prosystem       60 fps   320x240   audio=RUNNING
atari800      atari800        60 fps   336x240   audio=RUNNING   (.atr/.a52/.xex)
pce           beetlepcefast   60 fps   512x243   audio=RUNNING
zxspectrum    fuse            60 fps   320x240   audio=RUNNING
neogeo        fbalpha2012     59 fps   304x224   audio=RUNNING
mame          mame2003plus    59 fps   640x480   audio=RUNNING
n64           paralleln64     59 fps   640x480   audio=RUNNING
```

**N64 holds 59 fps.** That is well beyond what a 1.2 GHz Cortex-A7 with a
Mali-400 was expected to manage, and it is the pinned configuration doing the
work -- `glide64` (GLES2), HLE RSP, ARM dynarec, 640x480 internal. Left on
`auto` the core could have picked angrylion or cxd4 and it would have crawled.
(In the first run N64 showed `audio=PREPARED`; a second run showed `RUNNING`.
That was a sampling artefact, not a defect.)

The launcher went from `MENU: found 2 systems` to **15**, starting in 416 ms.

#### Correction: GBA must be gpSP, not mGBA

Earlier in this session the launcher's GBA entry was changed from
`gpsp_libretro.so` to `mgba_libretro.so`, on the reasoning that gpsp was the
core marked broken and mGBA was the one that built. That was wrong, and the
Lyra project had already solved it:

> **P2-4.4 — Switch GBA core from mGBA (interpreter) to gpSP (ARM dynarec) — full speed**
> mGBA uses a pure interpreter — every GBA ARM7TDMI instruction is decoded and
> executed in software. Too heavy for 3x Cortex-A7 @ 1.2 GHz.

So the original table was right and the change reintroduced a solved problem.
The real issue was the pinned commit: `d99f3ac` fails to assemble with modern
binutils ("changed section attributes for .jit"), which is why it had been
disabled. Repinned to `d6decfa351b575e2936afebba26d41ec20e4ddcd`, which builds
clean, and the dynarec is confirmed present in the binary (`translate_block_arm`,
`translate_block_thumb`, `dynarec_enable`, `init_dynarec_caches`) rather than
assumed -- an interpreter-only fallback would look identical from outside.
Result: **GBA at 60 fps.** mGBA still ships and can be selected by hand where its
accuracy is worth the speed.

The lesson: the reference project's log is a record of problems already solved on
this exact class of hardware. Reading it *before* changing a core choice would
have cost a minute; not reading it re-introduced a fixed bug.

#### Correction: the launcher does not filter by extension

I set out to "fix" the N64 entry because the ROMs are `.zip` and the table lists
`n64,v64,z64,ndd`. The board owner pointed out N64 was already listing and
running fine. Checking: `count_roms_in_dir()` counts every non-directory file,
and the `extensions` field of `SystemDef` is *declared and never read anywhere in
launcher.c*. It is documentation, not behaviour. No fix was needed, and the
change would have been noise.

#### Atari 800 -- core added and patched

92 `.atr`/`.a52`/`.xex` files were on the card with no core: the launcher already
had an `atari800` entry pointing at `atari800_libretro.so`, which did not exist,
so the system silently never appeared. Added as a package pinned to
`cd721790a0aa0e0772810949abcf5bd699c15371`.

Building it is not enough to make it usable. The Atari 8-bits are keyboard
computers and this device has no keyboard -- most titles want a keypress to start
or select a mode. The core renders a virtual keyboard (`virtual_kdb()` when
`SHOWKEY==1`) but upstream leaves the gamepad toggle commented out, so there is
no way to summon it. The Lyra project found this and patched L1 to toggle it.

Ported, with one deliberate difference: the Lyra put the toggle inside the
joystick-mode block, but that block sits under a `SHOWKEY==-1` guard, so it can
only ever *open* the keyboard. Placed instead right after `joypad_bits` is read
and before that guard, so the same button opens and closes it.

The same applies to ZX Spectrum: fuse only checks SELECT, and only inside a
switch on the port's device type, so if the device is anything else the overlay
is unreachable. L1 now toggles it unconditionally.

Both patches were generated by editing a copy of the real extracted source and
diffing it -- never by hand-writing a context diff. That caught a trap on the
first attempt: Python's text mode translates CRLF to LF on read, so writing the
file back rewrote every line and produced a 1566-line "patch" replacing the whole
file. Opening with `newline=''` preserves the original endings and gives the
27-line patch that was actually intended.

### Display rotated 180 degrees -- and why it is not a Settings item

The panel is mounted upside down in the case. Asked whether rotation should be
exposed in the launcher's Settings menu; the answer is no, for three reasons:

- **It is a hardware fact, not a preference.** Every unit built from this image
  has the panel the same way up. A toggle would imply a choice that does not
  exist.
- **It is a footgun.** A wrong value inverts the entire UI -- including the
  Settings screen needed to change it back.
- **Display and touch would desync.** Touch orientation lives in the device
  tree, so a runtime display toggle would rotate the picture and not the touch,
  leaving two sources of truth that can disagree.

So it is build-time, following the pattern already used for panel width and
height (`BR2_PACKAGE_RETROBPI_LAUNCHER_PANEL_*`).

**What the hardware can and cannot do**, checked rather than assumed:

- `sun4i-drm` exposes **no plane rotation property** -- there is no hardware
  rotation on this SoC.
- Our panel driver only programs the **TC358762**, which is a DSI-to-DPI format
  converter with no framebuffer and no scan-direction control. The glass
  controller is not addressable, so there is no panel-level flip either.

That leaves three consumers, each compensating separately, because nothing reads
a common knob:

| consumer | mechanism | cost |
| --- | --- | --- |
| RetroArch | `video_rotation = "2"` | free -- folds into the GL projection matrix (`gl2_set_rotation` -> `radians = M_PI * rotation / 180`) |
| launcher | `PANEL_ROTATION=180` at build time | one linear copy per redraw |
| touchscreen | device tree axis inversion | none |

`rotation = <180>` was added to the panel's DT node as the canonical record of
the fact. It does not rotate anything by itself -- the kernel only exposes it as
a connector hint -- but it puts the *reason* in one place, and every other site
carries a comment pointing back at it.

The launcher renders into a separate buffer which is copied reversed into the
dumb buffer on flip, rather than rotating the dumb buffer in place. In-place
would be cheaper but only correct if every frame is drawn in full; any partial
redraw on top of an already-rotated buffer would compound the rotation. 1.5 MB
buys immunity to a whole bug class. 180 degrees is also the cheap rotation --
a reversal of pixel order, no resampling, no stride change.

#### The touchscreen: a claim I had to withdraw

I first said the fix was to *delete* `touchscreen-inverted-x/y`, reasoning that
inverting both axes is itself a 180 degree rotation, so rotating the display
would double up. That reasoning depends on touch being correctly aligned to
begin with -- and checking the record, **touch alignment has never been verified
in this project or in the Lyra one.** Those two lines were written during the
initial port and never tested against a finger.

So they were left exactly as they are. Changing an untested setting in the same
step as a visible change would make the result uninterpretable: if touch came
out wrong afterwards there would be no way to tell which change caused it.

Whether they should stay depends on whether the digitizer shares the panel's
origin, which cannot be settled by reasoning. Kept on the grounds that a bonded
digitizer normally does, so an upside-down panel wants the correction. If touch
lands opposite to where you press, delete **both** lines -- deleting one gives a
mirror, which is considerably harder to diagnose than a clean 180.

**Pushed and confirmed live** (kernel, DTB, launcher and RetroArch config; the
DTB change needs a reboot):

```
launcher     DRM: initialized, double-buffered 800x480 XRGB8888, rotation 180
retroarch    video_rotation = "2"
device tree  panel@0/rotation = 00 00 00 b4   (180)
touch        touchscreen-inverted-x/y still present, unchanged
```

Two things a person still has to look at:

- **Is the UI actually upright now?** Three independent mechanisms have to agree;
  the logs prove each is *set*, not that the result looks right.
- **Does touch land where you press?** See the note above -- if it is 180 out,
  delete both inversion lines from the DTS, not one.

And one interaction to watch: RetroArch *adds* its `video_rotation` to whatever a
core requests, so a vertical MAME title (which calls `SET_ROTATION(3)`) lands at
180+90 = 270. That is arithmetically right, but vertical arcade games are the
case most likely to expose a mistake in the combination. Galaxian is a good test.

Boot console text stays upside down: `CONFIG_FRAMEBUFFER_CONSOLE_ROTATION` is not
enabled and turning it on is a separate kernel rebuild. With `quiet` and a ~4 s
boot it is a few seconds of upside-down text, judged not worth the rebuild yet.

### Rotation fallout: three reported issues, four fixes, one patch withdrawn

Display rotation worked in games. Three problems came back from testing, and
chasing them turned up a fourth.

**Touch was 180 degrees out.** Reported as "touch is not working", which is what
a 180 degree offset looks like on a virtual keyboard: pressing a key activates
the diagonally opposite point, usually empty space, so nothing happens at all.

The fix was the one predicted and then withdrawn as unproven -- delete both
`touchscreen-inverted-x/y`. Inverting both axes *is* a 180 degree rotation, so
with the display now rotated they applied it twice. Withdrawing the claim was
still right: it rested on touch being aligned beforehand, which had never been
verified, and the empirical answer arrived one test later at no cost. Removed as
a pair; removing one gives a mirror, which is much harder to read than a clean
180.

**RetroArch's menu and OSD stayed inverted while games rotated.** This is by
design, not a bug in RetroArch: `video_rotation` is a *content* rotation applied
to `gl->mvp`, while the menu, OSD and every `gfx_display` widget draw with
`gl->mvp_no_rot` so they stay screen-upright when a vertical arcade game
rotates. Entirely correct -- until the panel itself is upside down.

`screen_orientation` is the setting that would normally cover exactly this, but
the KMS context leaves it `NULL` in `video_driver.c`, so it is a no-op here.

Patch `0007-gl2-fold-display-rotation-into-base-projection` folds a fixed
display rotation into `mvp_no_rot` itself, so everything inherits it and core
rotation still composes on top for vertical games. `video_rotation` goes back to
`0`, keeping its normal meaning. The angle comes from the same Buildroot option
the launcher uses, so the mounting is still stated once.

**The atari800 keyboard patch was withdrawn -- upstream already does it better.**
Investigating the audio report surfaced `atari800_vkbd_enabled` in the core's
options, and this in `libretro-core.c`:

> SHOWKEY is also toggled at runtime by the mapped controller button (L3/R3)

The Lyra project hand-patched an older revision because that revision had the
toggle commented out. The commit pinned here fixes it properly: **L3 toggles the
virtual keyboard** (button 11 on the DS3), R3 for the 5200. The ported patch was
redundant and added a competing second toggle against the core's own
`last_vkbd_enabled` tracking, so it was deleted.

Worth stating as a general point: the reference project's log is a record of
problems solved *against the versions it pinned*. Porting a fix forward without
checking whether upstream has since fixed it properly is how you end up
maintaining a patch nobody needs.

**Atari 800 sound: not diagnosed.** The stream runs at real time and the sound
path is compiled and called (`pokey.o`, `pokeysnd.o`, `sound.o`,
`retro_sound_update()` in the run loop). An attempt to settle it by looping the
DAC back into the ADC and measuring the peak sample **failed** -- every reading
came back identical at 28006, including the silence reference, so it was
measuring a saturated ADC input rather than the DAC. No conclusion drawn from it.

The most likely explanation is not an audio bug at all: a `.atr` disk image
often sits at a boot prompt waiting for a keypress, and a machine that has not
booted anything makes no sound. That is testable now that L3 is known to raise
the keyboard.

**MAX_ENTRIES was silently truncating.** Spotted in the launcher log while
checking something else:

```
MENU: found 256 ROMs in Atari 2600 (663)
```

The system row showed the true 663 while the list stopped at 256, so 61% of that
collection was unreachable with nothing to say why -- the count came from
`count_roms_in_dir()` but the listing loop was bounded by `MAX_ENTRIES`. Raised
to 4096; `MenuEntry` is ~524 bytes and `g_menu` is static (BSS, not stack), so
it costs about 2.1 MB on a 512 MB machine. The loop now also logs a warning when
it hits the cap, turning silent data loss into a visible message.

### Touch: two independent bugs, and a long detour through the wrong one

Touch had never worked. After the display was rotated it was reported as "not
working", then "no response at all", then "seems like a SW bug" -- which was the
correct diagnosis, arrived at by the board owner while this log was still
chasing geometry.

There were two faults stacked, in different layers.

#### Fault 1 (the reason nothing responded): our polling patch never released

The controller does not report `TOUCH_EVENT_UP` when a finger lifts. It reports
`Reserved` for the vacated point, and the ISR skips those:

```c
type = buf[0] >> 6;
if (type == TOUCH_EVENT_RESERVED)
        continue;               /* slot is never closed */
```

With a real interrupt that is harmless -- the controller only interrupts when it
has something to say, so an UP arrives as its own event. Our patch 0004 polls
every 17 ms and reuses the handler unchanged, so it sees `Reserved` for the
lifted finger, skips it, and **leaves the slot open forever**.

The chain from there is exact: `ABS_MT_TRACKING_ID` never returns to -1,
`input_mt_report_pointer_emulation()` keeps computing `count > 0`, so
`BTN_TOUCH` stays 1 -- and because `input_event()` suppresses repeated values,
`BTN_TOUCH` is emitted **once**, on the first touch after boot, and never again.
Userspace sees coordinates streaming with no press or release. The launcher
registers a press only on `BTN_TOUCH`, so every touch UI looked completely dead
rather than merely offset.

Patch 0006 closes any slot the controller stopped reporting, guarded to polling
mode so IRQ behaviour is untouched.

#### Fault 2 (the orientation): touch must NOT be rotated with the display

Once events flowed, the orientation was wrong. Rather than derive it again, the
corners were measured with the launcher logging what it received:

```
viewer top-left      -> raw (8, 3)
viewer bottom-right  -> raw (787, 452)
```

The digitizer's origin is already at the **viewer's** top-left. It agrees with
the rotated display and needs no transform at all: the touch layer is bonded in
a different orientation from the LCD, so "the panel is mounted upside down" does
**not** imply "touch is upside down". An intermediate version rotated touch to
match the framebuffer and produced exactly inverted coordinates -- top-left read
as (791, 476).

Also worth recording: **touch is a search-keyboard-only feature by design.**
`touch_poll()` is called from exactly two places, both inside the search
keyboard, and `g_touch.just_down` is tested only there. Tapping the main menu
does nothing and never did. That cost a round of confusion when corner taps on
the menu logged nothing at all.

#### What went wrong in the diagnosis

The evidence for fault 1 was in hand early: a full decode of 336 captured events
showed only codes 53/54 (MT position), 0/1 (ABS_X/Y) and SYN -- no
`TRACKING_ID`, no `BTN_TOUCH`. That is the signature of the bug. It was
explained away as "captured mid-touch" because the rotation theory was already
in place, and evidence was made to fit it.

What followed was two external loggers, both silently lossy -- the first stuck
in `od`'s pipe buffer, the second using `dd bs=16 count=1` in a loop, which
reopens the device every iteration and drops everything in between, so it could
never show a press/release transition even in principle. Conclusions were drawn
from an instrument that could not measure the thing in question.

The fix was to instrument the program itself. Three `printf`s in `touch_poll()`
and the keyboard hit test settled in one round what the external tooling had
failed to establish in four. **When the question is "does this program receive
X", ask the program.**

### Jump-to-letter for long lists

With the 256-entry cap lifted, Atari 2600 lists all 663 ROMs -- at which point
the d-pad stops being navigation. Three tiers now:

```
UP / DOWN      one entry
L1 / R1        one page
LEFT / RIGHT   one letter group
```

LEFT/RIGHT were free in the lists (bound only in Settings, for theme and
volume), so nothing had to be displaced.

Two decisions worth recording:

- **Non-letters collapse into a single `#` group.** The list is sorted with
  `strcasecmp`, so "1942", "3-D Tic-Tac-Toe" and "720 Degrees" sit together at
  the top. Grouping them all as `#` means one press clears the whole numeric run
  instead of stepping through it title by title.
- **LEFT is strict**: it always lands on the first entry of the *previous*
  group, never "top of the current group first". The two-stage behaviour is
  right for skipping music tracks but wrong in a list, where the same button
  would do different things depending on where the cursor happened to sit.

`scroll_top` is deliberately not touched -- `ui_draw()` already clamps it to keep
the selection visible, and duplicating that is how the two drift apart.

**The letter overlay** shows the letter just jumped to, centred and large, for
30 frames. Counted in frames rather than wall time because the main loop is a
fixed ~30 Hz `usleep`, so a frame counter cannot drift out of step with the
redraws the way a clock read inside an event-driven loop can. The loop only
calls `ui_draw()` when something is dirty, so the countdown marks the frame it
reaches zero as dirty -- otherwise the overlay would linger until some unrelated
redraw happened to clear it.

Centred rather than tucked in the header corner: the point is to be readable
without looking away from where the eye already is while holding the d-pad. A
corner indicator is simpler but has to be hunted for, which defeats it.

#### A build check worth keeping

The stripped binary came out at exactly 46524 bytes three rebuilds running,
which looked like the build silently not happening. It was real -- `launcher.o`
grew 54096 -> 54736 bytes and was newer than the source each time; section
alignment simply absorbed the delta in the stripped output. Confirmed by md5ing
the binary here and on the board after pushing. **Stripped binary size is not a
reliable signal that a rebuild took effect**; object size, timestamps, or a hash
are.

### PlayStation: working, and a core that built fine but could not load

PSX runs. Capcom vs SNK on hardware:

```
found US BIOS file, crc32 37157331: /opt/roms/_system/bios/scph1001.bin
BIOS: 19951204, 'CEX-3000/1001/1002 by K.S.', 'A'

video : 59 fps
audio : 483560 frames in 10 s (real time 480000), state RUNNING
cpu   : 216 jiffies over 4 s  ->  54% of ONE core, of four
```

That is a lot of headroom, and considerably better than N64 -- which is the
expected shape: pcsx_rearmed was written for Pandora/GP2X-class ARM and its
build banner confirms the good path, `cc 14.3.0 32bit pic armv7 neon ari64
gpu=neon` (ari64 dynarec, NEON rasteriser, NEON GTE).

**On the GPU question:** the Mali-400 cannot help with PSX rasterisation. The
hardware-renderer PSX cores (beetle-psx-hw, DuckStation/SwanStation) need GLES3
or Vulkan features this GPU does not have -- it is GLES 2.0 only. The other PSX
core in this tree, `beetlepsx`, builds the *software* mednafen core, which is
accuracy-first and far heavier than pcsx_rearmed. So the CPU rasterises with
NEON and the GPU does only the final scale and present.

#### Two failures before it worked

**The pinned commit 404'd.** `c88070d1` no longer exists -- upstream rewrote
history, so codeload had nothing to serve. Repinned to a current master head
resolved from the GitHub API rather than guessed. Same failure mode as gpsp;
worth expecting on any long-dormant pin in this tree.

**Then the core built successfully and could not be loaded.** RetroArch reported
only `Failed to open libretro core`, which says nothing about why. The cause:

```
frontend/libretro-cdrom.c  calls dir_list_new() and compat_strcasestr()
Makefile                   OBJS += frontend/libretro-cdrom.o
                           ...but neither dir_list.o nor compat_strcasestr.o
```

The C compiles because the headers declare both, so the build succeeds and emits
a `.so` with two undefined symbols. Nothing complains until the frontend tries to
`dlopen` it. Patch 0001 adds the two objects.

A wrong turn on the way: the composite `platform="buildroot gles armv7 hardfloat
neon"` matches none of the exact names `Makefile.libretro` branches on, which
looked like an obvious culprit. Setting `platform=unix` changed nothing -- the
same two symbols were still missing. The `.mk` keeps `platform=unix` because
being explicit is right, but its comment now says plainly that this was **not**
the cause, so the next person does not inherit a wrong explanation.

#### A check that had been lying

Diagnosing this exposed an earlier claim in this log as worthless. The "all 18
cores resolve their runtime dependencies" verification ran:

```sh
ldd "$so" 2>/dev/null | grep -i 'not found'
```

**busybox has no `ldd`.** The command failed silently, grep read nothing, and
every core was reported OK. It could never have detected a problem. The real
check is `readelf -d` for NEEDED libraries and `readelf --dyn-syms` for undefined
symbols not exported by libc/libm -- which is what found this in a minute once
it was used. An instrument that cannot fail is not a test.

### N64: the hardware can do it, but not with a renderer that displays

Reported as choppy sound with good picture. The picture was the misleading part.

**With the GL renderers (glide64 / rice)** the emulator thread sits at 94-100% of
one core and the ALSA stream underruns constantly -- 10 of 12 one-second samples
broke with glide64, 5-6 with rice. RetroArch keeps flipping the display at ~60 Hz
regardless, which is exactly why the video looks fine while the audio breaks up.
Shipped `rice` over `glide64` on that measurement; it halves the xruns at the
same frame rate.

Measured as **not** helping: `send_allist_to_hle_rsp` (the obvious candidate --
no effect), internal resolution at 320x240, `video_threaded` (worse: it adds a
copy when the problem is compute, not present), `framerate=fullspeed` (worse).

**Then angrylion, which changes the picture entirely.** It is the software RDP
rasteriser, and it multi-threads -- `parallel-n64-angrylion-multithread` takes
`all threads` or an explicit count. It had been dismissed earlier in this log as
"a software rasteriser and hopeless here", which was an assumption about
single-threaded software rendering, not a measurement. The board owner asked
about the threading option, which is what prompted actually testing it.

Over 6 s, where 264600 audio frames is real time:

```
                                   audio+    fps   cpu
rice (GL, current shipped)           4862*    59   95%
angrylion all-threads, sync Low    294104      0   43%
angrylion all-threads, sync High   291700      0   39%
angrylion all-threads, sync Medium 292314      0   44%
angrylion SINGLE thread, sync Low  290931      0   41%
```

`* rice's figure is corrupted` -- appl_ptr resets to zero on every re-prepare, and
rice xruns constantly, so its delta cannot be read as a rate. Angrylion's is
clean because it never xruns.

So **angrylion runs N64 at full speed with perfect audio at ~40% CPU**, and shows
nothing at all. Zero vblanks over 6 s in every configuration, including
single-threaded, so it is not a threading or sync problem: this build simply
never presents a frame with angrylion selected. The GL context comes up fine and
takes the software path correctly (`SET_PIXEL_FORMAT: XRGB8888`, GLSL shaders
linked, and notably **no** `SET_HW_RENDER`, unlike rice) -- it is just never
handed a frame.

The useful conclusion is not "N64 is too slow for this board". It is that **the
CPU can run N64 at full speed when the RDP work is spread across four cores**,
and the renderer that can do that is the one that does not display. The GL
renderers display but keep everything on one core, which the SoC cannot sustain.

Worth trying if this is picked up again: why angrylion produces no frames (the VI
overlay path in the core), or the plain `mupen64plus` core, which is in the
package tree with its own renderer set.

#### Traced: where the missing frame is lost

Static trace of the core source, done after the board went off. This does not
identify the cause, but it narrows it to a handful of lines and gives a cheap
next experiment.

RetroArch only ever sees a frame via `emu_step_render()` in `libretro/libretro.c`,
and that function pushes one **only if `flip_only` is set**:

```c
bool emu_step_render(void) {
   if (flip_only) {
      switch (gfx_plugin) {
         case GFX_ANGRYLION:
            video_cb(prescale, screen_width, screen_height, screen_pitch);
```

`flip_only` is assigned from exactly one place -- `retro_return(just_flipping)` --
and for angrylion the only caller is:

```c
/* mupen64plus-video-angrylion/interface.c:145 */
void vdac_sync(bool invalid) { retro_return(!invalid); }
```

So **every frame angrylion presents depends on `vdac_sync` being called with
`invalid == false`**, and `n64video/vi.c` reaches it through three early-outs that
all report the frame invalid:

| vi.c | condition | result |
|---|---|---|
| 664 | `!frame_buffer` -- VI_ORIGIN is 0 | `vdac_sync(true)` |
| 346 | `isblank && prevwasblank` -- two blank frames in a row, `isblank = (ctrl.type & 2) == 0` | `return false` |
| 444 | `!validh` -- `hres <= 0 \|\| h_start >= PRESCALE_WIDTH` | `return false` |
| 766 | otherwise | `vdac_sync(!valid)` |

Any of those produces exactly the signature measured: the CPU emulates flat out,
the audio callback runs at full rate, and `video_cb` is never called, so vblanks
stay at 0. The GL plugins do not go through this path at all -- they push
`RETRO_HW_FRAME_BUFFER_VALID` from the `default:` case -- which is why they
display from the same VI register state.

**Cheap experiment when the board is back:** `vi.c:759` picks the renderer by
overlay mode --

```c
if (config.vi.mode == VI_MODE_NORMAL) valid = vi_process_full();
else                                  valid = vi_process_fast();
```

Our shipped `vioverlay` is `Filtered`, which maps to `angrylion_set_vi(0)` =
`VI_MODE_NORMAL` = `vi_process_full`. Setting `vioverlay` to `Unfiltered`,
`Depth` or `Coverage` routes through `vi_process_fast` instead -- a separate
function with its own validity logic. That is a one-line `.opt` change and a
single run, and it distinguishes "angrylion is broken here" from "vi_process_full
specifically is broken here". None of the earlier matrices varied this option;
they varied thread count and sync level, which the trace above shows are
downstream of the validity decision and therefore could not have mattered.

#### The vi_process_fast hypothesis, tested and refuted

The trace above predicted that `vioverlay` was the one option never varied, and
that switching it off `Filtered` would route through `vi_process_fast` instead of
`vi_process_full` -- a separate function with its own validity logic. Tested on
the board across all four overlay modes, with rice as a control:

```
                              vblanks/6s   audio+      verdict
rice (control)                     +361    (reset)     presenting, ~60 fps
angrylion Filtered   (full)         +57    291224      nothing
angrylion Unfiltered (fast)         +52    293232      nothing
angrylion Depth      (fast)         +55    293544      nothing
angrylion Coverage   (fast)         +58    (reset)     nothing
```

**Refuted.** `vi_process_fast` behaves exactly like `vi_process_full`. Angrylion
presents no frames in any overlay mode, so the failure is upstream of the
mode selection at `vi.c:759`, not inside either renderer.

#### The vblank counter has an idle baseline -- calibrate before reading it

This run nearly produced a false positive. `+55` over 6 s reads as "9 fps" if you
assume the counter rests at zero, which would have looked like angrylion
partially working. It does not rest at zero:

```
nothing running (no DRM client at all) : +133  
launcher only                          : +93  
nothing running (repeat)               : +126  
```

IRQ 142 is `1c0c000.lcd-controller`, which ticks for reasons other than a client
presenting a frame. So angrylion's +52..+58 is **at or below the idle floor** --
indistinguishable from no output -- and the only sound discriminator is rice's
+361, which is 3x the floor. Every future frame-rate claim from this counter has
to be read against a same-session idle measurement, never against zero.

This also casts doubt on the earlier "0 vblanks" figures for angrylion recorded
above: a free-running counter should have shown ~130 at idle, so those runs were
measuring under conditions that differed somehow. It does not change the
conclusion -- rice-vs-baseline is unambiguous in both sets -- but the specific
number 0 should not be trusted.

Two other columns in that table are unusable and are marked so rather than
quietly dropped: the CPU percentages came from `top -b -n1`, whose first sample
is cumulative-since-boot and therefore meaningless, and the `(reset)` audio
cells went negative because an xrun re-prepared the stream and reset `hw_ptr`.
Angrylion's audio figures are valid: ~291k frames per 6 s against 288000 expected
at 48 kHz, i.e. still full speed with no xruns.

#### Where this leaves N64

Config-level options are exhausted: gfx plugin, RSP plugin, resolution, framerate,
alist offload, thread count, sync level and now VI overlay have all been measured.
N64 stays on **rice**, which displays and xruns least. Angrylion remains the
interesting result -- full-speed emulation with clean audio at low CPU, no
picture -- and moving it forward now needs instrumentation inside the core
(a printf at the three `vi.c` early-outs to see which one fires), which means
rebuilding the core rather than editing a `.opt` file.

#### Root cause found: every frame is discarded at the `validh` check

Instrumented the core itself -- a throwaway build with probes at each early-out
in `n64video_update_screen` and `vi_process_full`, writing to a file. With a
20000-event cap, over 14 s of Mario Kart 64 under angrylion:

```
  26  no_framebuffer   origin=0 status=0 width=0 vsync=0      <- boot frames only
 713  validh_fail      hres=ffffff94 (-108)  h_start=0
 713  sync_invalid     origin=0000027f status=00003116 width=00000140 vsync=0000020d
```

**Every frame after boot dies at `validh`.** In `vi_process_full`:

```c
bool validh = hres > 0 && h_start < PRESCALE_WIDTH;
if (!validh) return false;          /* -> vdac_sync(!valid) -> flip_only=0 -> no video_cb */
```

`hres` is **-108**, so `validh` is false, so the frame is dropped, 713 times in
14 s -- i.e. the VI is ticking at ~51 Hz and discarding every single frame.

Where -108 comes from, in `n64video_update_screen`:

```c
h_start = (*vi_reg_ptr[VI_H_START] >> 16) & 0x3ff;   /* = 0 */
h_end   =  *vi_reg_ptr[VI_H_START]        & 0x3ff;   /* = 0 */
hres    = h_end - h_start;                           /* = 0 */
...
h_start -= (ispal ? 128 : 108);                      /* = -108, NTSC */
if (h_start < 0) { hres += h_start; h_start = 0; }   /* hres = -108 */
```

So the whole failure reduces to **`VI_H_START` reading zero**.

#### The VI register dump

All 14 VI registers, sampled once the game is running:

```
STATUS=0000311e  ORIGIN=0000027f  WIDTH=00000140  INTR=00000002
V_CURR=00000000  TIMING=03e52239  V_SYNC=0000020d  H_SYNC=00000c15
LEAP=0c150c15    H_START=00000000 V_START=002501ff V_BURST=000e0204
X_SCALE=00000200 Y_SCALE=00000400
```

Twelve of the fourteen are textbook NTSC: `TIMING=0x03e52239`, `V_SYNC=0x20d`
(525 lines), `H_SYNC=0x0c15`, `LEAP`, `V_BURST`, `V_START=0x002501ff`,
`X_SCALE=0x200` (1.0), `WIDTH=0x140` (320). Two are not:

- `H_START = 0` -- should be roughly `0x006C02EC`
- `ORIGIN  = 0x27f` -- 639, not an RDRAM address

The PIF boot ROM HLE (`pifbootrom.c:94`) sets only three VI registers:
`V_INTR=1023`, `CURRENT=0`, and `H_START=0`. It does **not** write TIMING,
V_SYNC, H_SYNC, LEAP, WIDTH, X_SCALE, Y_SCALE or V_START -- so those eleven
correct values came from the game. The game is running and configuring the VI
normally; `H_START` alone never receives a real value and stays at the boot
default of 0.

Noted but **not established**: if `0x27f` (currently in ORIGIN) were the value in
`H_START`, the arithmetic would give h_end=639, h_start=0, hres=639, then
639-108 = **531** -- a perfectly valid width. That is suggestive of a register
mix-up, but the obvious candidate was checked and cleared: `plugin_get_vi_registers()`
casts `&gfx_info.VI_STATUS_REG` to a `uint32_t**` array, and GFX_INFO's field
order in `m64p_plugin.h` matches angrylion's `enum vi_register` in `n64video.h`
field-for-field. The HACK comment above that cast is accurate; the ordering is
genuinely correct. Where the H_START write is actually lost is not yet known.

#### What this retracts

Earlier in this log, and in what was reported at the time, angrylion's behaviour
was summarised as *"runs N64 at full speed with perfect audio at ~40% CPU"*, and
the conclusion drawn was that the CPU can sustain N64 once RDP work is spread
across four cores. **That conclusion is wrong and is withdrawn.** Angrylion
returns from `vi_process_full` before doing any rasterisation at all -- it was
not rendering quickly, it was not rendering. Low CPU and xrun-free audio are what
a renderer that does nothing looks like. Nothing in these measurements says
anything about whether this SoC could sustain N64 with a working software
rasteriser; that question is untested.

The measurable position on N64 is unchanged: `rice` is shipped, it displays, and
it xruns less than glide64. Nothing here improves in-game N64 audio.

#### Reproducing / continuing

The probe patches are not kept in the package -- they were applied to the build
tree, and `vi.c` has been restored from its `.orig` and the core rebuilt clean,
so `target/` holds a stock binary again. To pick this up:

1. Instrument `vi_process_full` and `n64video_update_screen` per the scripts in
   `scripts/instrument_vi*.py` (they patch from a pristine `.orig` each run).
2. **RetroArch's stdout/stderr is discarded on this device** -- even `-v` yields a
   0-byte log, for the stock core too. Probes must write to their own file.
   Two runs were wasted before this was noticed; the empty log initially read as
   "the code never executes", which was wrong.
3. The next question is where the game's `VI_H_START` write goes. `plugin.c:149`
   wires `gfx_info.VI_H_START_REG = &g_dev.vi.regs[VI_H_START_REG]`, so the trace
   continues into the VI register write path in `mupen64plus-core`.

#### Two vacuous checks, recorded so they are not repeated

While chasing this I twice concluded "angrylion is not compiled in" from a symbol
count of zero. Both were worthless:

1. `readelf` was run against `parallel_n64_libretro.so`, but the package installs
   it renamed to `paralleln64_libretro.so`. readelf failed, printed usage to
   stderr, and `grep -c` counted zero matches in the empty stdout. **A zero from a
   command that failed is not a measurement.**
2. Corrected to the right filename, it still read zero -- because the core links
   with `-Wl,--version-script=link.T`, which localises everything except
   `retro_*`, and Buildroot strips the binary. There is no symbol table to search.

The check that actually works on a stripped, version-scripted object is `strings`:
13 angrylion strings are present, including `ANGRYLION_NUM_THREADS` and the full
option list, and the object files `n64video.o`, `parallel_al.o` and `interface.o`
all exist in the build tree. Angrylion is built in and has been all along.

This is the same shape as the `ldd` mistake earlier in this log -- a check whose
"pass" is produced by the check being unable to fail.

#### A measurement correction

Earlier in this log N64 is recorded as running "59 fps" alongside the other
systems, presented as a success. That number is the LCD controller's vblank rate
-- the display flipping, including duplicated frames -- not the speed of the
emulation. On a core that cannot keep up, the two are unrelated. Frame rate
measured at the display is only a proxy for emulation speed when the emulator is
actually keeping up, which is the case it cannot be used to establish.

### N64, night session: two refutations and a real lead

Continued after the root cause above (every frame discarded at `validh` because
`VI_H_START` reads 0). The question was why that register never gets a value.

#### The decisive measurement: the game behaves differently per renderer

Instrumented `write_vi_regs` in `mupen64plus-core` -- shared by every plugin --
and ran the *same binary* under both renderers. Counting distinct values rather
than the first N writes:

```
rice:      origin_writes=572  distinct_origin=224  hstart_writes=571  hstart_nonzero=504
angrylion: origin_writes=715  distinct_origin=1    hstart_writes=714  hstart_nonzero=0
```

Under rice the game double-buffers across **224 distinct framebuffer addresses**
and sets `H_START` non-zero 504 times. Under angrylion it writes **one**
framebuffer address, ever, and `H_START` is zero on all 714 writes. Same core,
same ROM, same instrumented binary -- so this is not a rendering failure at all.
**The emulated game is stuck**, spinning on something and never swapping buffers.
`VI_H_START=0` is a symptom, not the cause.

#### Refuted: the forced LLE RSP

`libretro.c` silently overrides the configured RSP when angrylion is selected:

```c
if (gfx_plugin == GFX_ANGRYLION)
    rsp_plugin = RSP_CXD4;      /* ignores our rspplugin="hle" */
```

A game hanging under a slow/incorrect LLE RSP fits the symptom exactly, so this
looked compelling. Patched it out, rebuilt, re-ran the same instrumentation:
**`distinct_origin=1`, `hstart_nonzero=0` -- byte-identical.** The RSP choice
makes no difference. Refuted.

#### Refuted: the undelivered DP interrupt

An LLE RDP signals display-list completion by setting `DP_INTERRUPT` in
`MI_INTR_REG` and calling `gfx_info.CheckInterrupts()`. In `plugin.c` that
callback is wired to a no-op:

```c
gfx_info.CheckInterrupts = EmptyFunc;
```

So angrylion's `plugin_sync_dp()` raises the bit and nothing delivers it -- and a
game waiting on RDP completion would hang precisely as observed, while the HLE
renderers are unaffected because the core finishes their display lists itself.
This is a genuine defect in the fork regardless. Wired it to the real path:

```c
static void GfxCheckInterrupts(void) { raise_rcp_interrupt(&g_dev.r4300, MI_INTR_DP); }
```

Rebuilt and tested: still nothing on screen. Refuted as *the* cause, though the
no-op callback remains suspicious and may be one of several things wrong.

Both experiments have been reverted; the build tree is pristine and the shipped
core is stock. Neither patch is carried in the package.

#### Not the cause: CPU clocking

Checked directly rather than assumed. DCIN is present so `S05powercap` does not
clamp, the governor was `schedutil`, and all four cores sit at the full
1200000 kHz with `cpuinfo_max_freq` also 1200000. No thermal zone is exposed. The
board is not underclocked or throttled.

#### The real lead: cpufreq governor

`schedutil` scales on demand, which is the wrong behaviour underneath a real-time
audio thread -- it was observed dipping to 1104000 kHz mid-game. Measuring actual
audio health (polling the PCM substream 10x/s for 20 s, counting `hw_ptr` going
backwards, i.e. the stream being re-prepared after an underrun):

```
governor=schedutil    xrun_resets=15  non_RUNNING=29/200  min_cpu0_freq=1104000
governor=performance  xrun_resets=10  non_RUNNING=17/200  min_cpu0_freq=1200000
```

This is the first change measured to reduce N64 xruns rather than move them
around, and unlike everything else tried it targets the actual complaint (choppy
sound) instead of the renderer. Single samples though, so it is being repeated
interleaved before anything is shipped -- see below.

#### Shipped: N64 audio, roughly three quarters of the dropouts removed

Two changes, both measured, both narrow.

**1. Pin the cpufreq governor to `performance` on DCIN** (`S05powercap`).
`schedutil` reacts to load after it appears, which is wrong underneath a
real-time audio thread; it was caught dipping to 1104 MHz mid-game. Not applied
on the VBUS path -- there the governor is left free to drop to idle frequencies,
because holding the capped 648 MHz continuously is exactly what that 900 mA
budget cannot spare.

**2. `audio_latency = "256"` as an N64-only override**
(`config/ParaLLEl N64/ParaLLEl N64.cfg`, loaded because `auto_overrides_enable`
is already true). 256 is the knee -- 320 measured identically, so the extra delay
would buy nothing. The core's own `parallel-n64-audio-buffer-size` was tested at
2048 and 4096 and made no difference, so it is untouched.

Measured on Mario Kart 64, polling the PCM substream 10x/s for 15 s, counting
`hw_ptr` going backwards (an underrun re-preparing the stream), three
interleaved rounds:

```
                          xruns        non-RUNNING samples
OLD  schedutil + 128      9,  8,  9    19, 16, 18
NEW  performance + 256    2,  2,  3     9,  9, 10
```

**~73% fewer dropouts.** The cost is about 128 ms more audio delay, and only on
N64 -- every other system keeps the 128 ms global default. If the lag turns out
to be more irritating than the crackle, 192 is the middle setting (3-4 xruns) and
still clearly better than the default; the trade is documented in the override
file itself.

Both were verified live on the board, including that `S05powercap start`
actually flips the governor (`before: schedutil` / `after: performance`).

##### One near miss worth recording

The first run of this verification reported the new config at 6 xruns instead of
2, and the numbers looked plausible enough to ship. They were wrong: `scp` had
failed with `ambiguous target` because the destination path contains a space
(`ParaLLEl N64/`), so the override never reached the board and the "new" column
was really the governor change alone at latency 128 -- which is why it matched
the earlier governor-only figure of 6,6,6 exactly. It was caught only because the
script prints `override=present|MISSING` at the end. Remote paths with spaces
need quoting for the remote shell as well as the local one:

```
scp local "root@$B:'/root/.../ParaLLEl N64.cfg'"
```

Have the harness assert its own preconditions and print them next to the results;
a plausible number from a setup that silently did not apply is the failure mode
that actually costs time here.

### N64 dropouts solved: `alsathread` (NOT the whole story -- see below)

The choppy N64 sound is fixed, and the fix is one line.

RetroArch's `alsa` driver writes to the sound card inline in the emulation loop.
N64 is the only system that saturates this SoC, so when the emulator thread
briefly missed its deadline the card starved -- the stream underran, re-prepared,
and that is the crackle. `alsathread` does the same writes on its own thread, so
a late frame no longer starves the card.

Measured on Mario Kart 64. `hw_ptr` going backwards is one underrun; a *negative*
net rate means the stream kept resetting:

```
audio_driver=alsa        N64  rate -16767 Hz    <- stream repeatedly reset
audio_driver=alsathread  N64  rate  50040 Hz    0 xruns
```

Checked for regressions on four other systems -- NES, SNES, GBA, PSX -- all at the
correct rate with zero xruns on `alsathread`, none crashed. So it is set globally
in `retroarch.cfg` rather than per-core.

Shipped config, three rounds, preconditions asserted in the harness:

```
audio_driver=alsathread  audio_latency=128  governor=performance
round1  xruns=0  audio_rate=47040 Hz  fps=58
round2  xruns=0  audio_rate=50236 Hz  fps=62
round3  xruns=0  audio_rate=47094 Hz  fps=58
```

**This supersedes last night's `audio_latency=256` override, which has been
deleted.** That traded ~128 ms of extra audio delay for a partial fix (2-3
xruns). `alsathread` reaches *zero* at the normal 128 ms, so nothing pays a lag
penalty now. The `performance` governor change is kept -- it is an independent
win and still measurably helps.

Progression, for the record: 9-10 xruns originally, 6 with the governor alone,
2-3 with the governor plus the latency hack, **0** with alsathread.

#### A number that looked perfect and was nearly shipped wrong

An intermediate run reported alsathread at 0 xruns but with audio advancing at
"28% of expected" -- which would have meant the game running at a third speed and
sounding awful. It was neither shipped nor dismissed; it was checked. The
expectation was wrong, not the result: that script read `hw_ptr`, then ran a
150-iteration polling loop, then read it again, so the real window was about 4
seconds rather than the 15 I was comparing against. Re-measured with a
time-based window and the negotiated rate dumped from `hw_params`, alsathread
runs at exactly real time (48000 Hz negotiated, `hw_ptr` +721664 over 15 s) at
59 fps.

Two lessons, both already bitten this session: derive the expected value from
measured elapsed time rather than intended sleep duration, and pair a
"health" metric (xruns) with a "is it actually doing the work" metric (rate,
fps) -- a stream that has stopped never underruns either.

#### The stale-target trap, fourth occurrence -- and now guarded

Deleting `ParaLLEl N64.cfg` from the overlay did **not** remove it from the
image. Buildroot's `target/` is incremental, so the previously-installed copy
survived, and the first image built "without" the override still carried
`audio_latency = "256"` -- i.e. the 128 ms of lag that had just been declared
removed. Caught only by checking the built tree rather than trusting the source
change:

```
$ ls target/root/.config/retroarch/config/ParaLLEl N64/
ParaLLEl N64.cfg      <- should not exist
ParaLLEl N64.opt
$ grep -v '^#' "…/ParaLLEl N64.cfg"
audio_latency = "256"
```

The md5 of the image changed from `2e991001…` to `81cb8c48…` once the file was
actually gone, which confirms it had been baked in rather than merely lingering
in a scratch directory.

`post-build.sh` now removes that path explicitly and, more usefully, asserts the
outcome -- it hard-fails the build if `audio_driver = "alsathread"` is not what is
actually in the shipped `retroarch.cfg`, or if the N64 latency override is still
present in `target/`. The removal fixes today; the assertion is what stops the
next rename from silently shipping the old file. That is the fourth time this
directory's incrementality has produced a wrong image, and the first time there
is a guard rather than a comment.

#### Human verification: much improved, but not clean -- and the metric missed it

Gil tested the shipped build: *"Much improved! still very small breaks here and
there, good for now."*

That is a real improvement confirmed by ear, and it is also a **measurement gap
worth taking seriously**: the harness reported `xruns=0` on every one of the
final rounds, while the device still audibly breaks up occasionally. So zero on
this metric does not mean clean audio.

The metric counts `hw_ptr` going *backwards* -- i.e. the ALSA stream being
re-prepared after a full underrun. It cannot see:

- a near-miss where the buffer drains low but the writer catches up before the
  card runs dry (no reset, no backwards jump, still audible as a tick)
- samples dropped or duplicated by RetroArch's dynamic rate control while it
  resamples to keep the buffer centred (`audio_rate_control_delta`)
- a brief stall shorter than the ~100 ms polling interval
- anything wrong with the *content* of the samples rather than their timing

The last point is the general trap this log keeps hitting: the stream can be
perfectly healthy and still carry the wrong audio.

**Better instrumentation for next session**, in rough order of cost:

1. `/proc/asound/card0/pcm0p/sub0/status` also exposes `avail` -- sample the
   buffer *fill level* continuously and record the minimum. A margin that
   repeatedly approaches zero is the near-miss case, invisible today.
2. ALSA keeps an xrun counter per substream independent of `hw_ptr`; cross-check
   against it rather than inferring resets.
3. Poll far faster than 10 Hz, or better, have the measurement come from inside
   RetroArch rather than by polling proc from a shell loop.
4. Try `audio_rate_control_delta` variations again now that alsathread is in
   place -- it was tested against the old `alsa` driver, where underruns swamped
   any effect it might have had.

Also still open and cheap to try: raising `audio_latency` *on top of*
alsathread (they were only ever tested as alternatives, never combined), and
`parallel-n64-audio-buffer-size`, which showed nothing under `alsa` but was never
retested under alsathread.

State at handoff: board, `firmware/sdcard.img` (md5 `81cb8c48...`) and the build
tree verified byte-identical across all 27 checked files plus kernel and dtb.
Gil has taken a full backup of the project.

### The remaining breaks are NOT an audio-delivery problem

Gil played two instrumented sessions. The result is a clean negative that
redirects the whole investigation.

#### Session 1: one genuine underrun, and a broken detector

A real dropout was captured at t=142 s -- margin collapsed from a healthy ~119 ms
to 8 frames (0.16 ms), the card starved, and the stream was re-prepared
(`trigger_time: 142.855` confirms the restart):

```
142 NEWWORST margin=8frames 0ms
142 8 0 6136 RUNNING
142 RESET hw_ptr 5293056 -> 64
```

But the detector then went blind: `avail_max` is reset by the kernel when the
stream re-prepares, while the watcher tracked an all-time maximum, so nothing
could exceed the bar that event had set.

#### `avail_max` is unusable on this driver -- a claim that was simply wrong

The watcher was rewritten to re-arm on that reset, and the rewrite immediately
disproved the premise it was built on. `avail_max` had been described here as
authoritative because "the kernel maintains it continuously and therefore cannot
miss an event". It does not behave that way on this driver: it oscillates and
resets constantly --

```
400 REARM avail_max reset 4608 -> 1512
400 REARM avail_max reset 1528 -> 136
400 REARM avail_max reset 1528 -> 72
```

-- producing **15115 spurious "new worst" events and 772 "rearm" events in 25 s**,
and filling the log at ~600 lines/s. All avail_max logic was removed. What
survives is measured-trustworthy: `delay` sampled at ~700 Hz (a real collapse
lasts far longer than the 1.4 ms sampling gap) and `hw_ptr` going backwards,
which is what actually caught the genuine event above.

#### Session 2: the decisive negative

Gil reported an audible break at ~t=609 s. The margin either side of it:

```
605 MIN 4600 95ms
606 MIN 4608 96ms
607 MIN 4616 96ms
608 MIN 4592 95ms   <- the reported break
```

Rock steady. Zero underruns, zero dips below 64 ms, and the worst single second
in the entire run was 92 ms -- still enormously healthy.

There is a stronger conclusion inside that stability. `hw_ptr` advances at exactly
48 kHz (hardware clock), and `delay = appl_ptr - hw_ptr` stayed constant through
the break. Constant delay with a fixed-rate consumer means the producer supplied
**exactly the right number of samples at exactly the right rate**, continuously,
straight through the event.

Delivery is therefore perfect, and the defect is in the **content** of the
samples. That rules out the entire class of fixes pursued so far -- audio latency,
ALSA buffer size, threaded driver, cpufreq governor. Those fixed a real problem
(the session-1 underrun is exactly what they eliminate) but cannot touch this one.

#### An objective glitch detector, and the mistake that wasted it

Since the defect is in sample content and no one can be asked to listen to every
A/B, the core's audio backend was instrumented to count large sample-to-sample
discontinuities -- a click or pop is a big jump between adjacent samples. Four
configurations were compared: `send_allist_to_hle_rsp` enabled/disabled against
`audio-buffer-size` 2048/4096. All four reported **zero** glitches.

The detector is not broken -- it reports per-second peak jumps in the 5000-7000
range, topping out at 10244, so it is demonstrably scanning real audio with real
dynamics. The runs were worthless for a different reason: **they measured 45
seconds of the title screen.** Gil's whole point was that the breaks only happen
deep in gameplay. This is the third time in this investigation that a measurement
has been taken against the attract screen rather than a race, and the second time
it produced a confident, useless number.

Any future N64 audio measurement has to be taken during real play. The tooling
now supports that directly: `scripts/glitch_session.sh install` swaps in the
instrumented core, the detector logs continuously while the game is played, and
`collect` reports discrete glitch events plus the per-second peak-jump timeline
so an anomalous second stands out against the normal 5000-7000 band. `restore`
puts the stock core back. The board currently has the **stock** core installed
and verified (0 instrumentation markers).

#### What the next session should distinguish

- peak jump spikes far above the normal band at the moment of an audible break
  -> the emulator really is generating corrupt samples; chase the core's audio
  path, starting with the resampler ratio change on `aiDacrateChanged` (a
  stateful sinc resampler whose ratio changes mid-stream will click).
- peak jump stays in band -> the artefact is not a discontinuity at all. Then it
  is likely a brief *repeat* or *silence* of correct amplitude, which needs a
  different detector (correlate consecutive batches), or the perceived break is
  a video stutter rather than an audio one.

### The dirt is the emulator running slow, and rate control hiding it

Gil, from experience on other projects: *"this type of sound is either CPU not
able to keep up"*. He was right, and the measurement is unambiguous.

Instrumented the core to compare audio-seconds produced against wall-seconds
elapsed. Over a real race:

```
audio produced : 161.2 s
wall clock     : 184.4 s
ratio          : 0.874          <- emulator runs at 87% of real time
```

```
average speed_permille : 868   (1000 = real time)
seconds below 980      : 155 of 161
seconds below 950      : 137 of 161
worst seconds          : 641, 645, 675, 694, 699 ...
```

#### Why every previous measurement said the audio was perfect

This is the important part, and it invalidates the reasoning behind four earlier
rounds of investigation. RetroArch's dynamic rate control continuously adjusts
the resampling ratio to hold the ALSA buffer at its target. When the emulator
produces less audio than real time, DRC **stretches** it. The consequences:

- the ALSA margin sits rock steady at 96 ms -- *because* DRC is holding it there.
  "The buffer is healthy" was never evidence that the audio was healthy.
- there are no underruns, so `hw_ptr` never goes backwards.
- the samples are well-formed: no clipping (after the headroom fix), no aliasing
  (HF/LF 0.0001), no discontinuities.
- and the audible defect is **the stretch ratio itself modulating**, second to
  second, between 0.85 and 1.10 in one 20-second stretch.

Continuously varying pitch and timing is exactly what "a bit dirty" describes.
Every detector built so far measured the buffer or the sample values -- the two
things DRC is specifically designed to keep looking correct. The metric that
mattered was the one never measured until now: emulation speed against a clock.

#### A correction on where the time goes

An earlier note in this session claimed the emulator thread was "pinned on CPU0,
fighting every interrupt". That came from a **single snapshot** of
`/proc/PID/task/*/stat`; resampling showed the thread on CPU3, so it migrates and
the claim was overreach. Also, `taskset` on this busybox reports empty affinity
and silently applied nothing, so the pinning attempted at the time never happened.

What is solid:

```
emulator thread : 88% of one core
whole system    : 75% idle
```

88% rather than 100% matters: a purely CPU-bound thread would peg. Blocking for
~12% of the time points at waiting on the Mali finishing each frame, i.e.
GPU-bound rather than CPU-bound -- which implies reducing *render* work, not
finding more CPU.

Interrupt spreading was applied and did take effect (Mali gp/pp0/pp1 moved to
CPU2, Bluetooth UART to CPU1, audio DMA and LCD left on CPU0). All six had been
landing on CPU0. It is not sufficient by itself.

#### The metric to use from now on

`speed_permille` from the core, measured **during actual racing**. Three separate
times in this investigation a confident conclusion was drawn from 45 seconds of
the Mario Kart title screen, which loads the machine nowhere near a race. The
attract-mode demo solves this: leave the ROM running ~75 s and it starts
demo-racing itself, giving repeatable automated A/B under realistic load with no
human in the loop.

#### Fixed, confirmed by ear: render at native 320x240

```
rice 640x480 original     avg speed 809/1000   worst 757
rice 320x240 original     avg speed 998/1000   worst 943   <- shipped
glide64 640x480 original  avg speed 803/1000   worst 324
rice 640x480 fullspeed    avg speed 814/1000   worst 769
```

At native resolution the emulator runs at **998/1000 -- essentially exactly real
time** -- so dynamic rate control has nothing left to stretch and the modulation
that was audible as dirt disappears. Gil: *"Sound fixed, graphics is not nice as
before but it is good enough, taking into account this is the real resolution."*

320x240 is the N64's actual output resolution. The previous 640x480 was 2x
supersampling -- an enhancement, not a baseline -- and this SoC cannot afford it.
A faster GPU would allow it again, which is the honest summary of the trade.

The emulator sitting at 88% CPU rather than 100% was the tell that this is
**GPU-bound**: it blocks ~12% of the time waiting on the Mali. That is why
dropping render resolution recovers the whole deficit while nothing CPU-side did.

#### Correcting a note that was wrong in this very file

The shipped `.opt` previously recorded 320x240 as *"measured as NOT helping"*.
That note was wrong. It had been measured against ALSA xrun counts during
45 seconds of the title screen -- wrong metric, wrong load -- and it actively
discouraged the change that turned out to be the fix. It has been replaced with
the speed measurements above and an explanation of why the old number was
meaningless.

Three separate times this investigation drew a confident conclusion from the
Mario Kart title screen. The attract-mode demo removes the excuse: leave the ROM
running ~75 s and it races itself, giving repeatable automated A/B under real
load.

#### Kept on their own merits

Three core-side audio fixes were found along the way. None was the cause of the
reported dirt, but each is a genuine defect and all are retained, now as package
patches (`0002-n64-audio-headroom-and-native-48khz.patch`,
`0003-n64-declare-48khz-sample-rate.patch`) rather than edits to the build tree,
so a `dirclean` cannot lose them:

- **Headroom** (0.8 = -1.94 dB before the resampler). Clipping was real and
  measured: 436 samples pinned at full scale, peak 32768, overshoot 1060
  permille. The clamp is downstream in `convert_float_to_s16`, so no ALSA volume
  setting could have fixed it.
- **Native 48 kHz output.** Was a hardcoded 44100 against a 48000 codec, i.e.
  two resampling stages. Now one, at exactly 1.5 for a 32 kHz game, with the
  frontend performing no conversion at all. Verified on a captured stream:
  >16 kHz energy at -116 dB, HF/LF 0.0001.
- **Resampler quality** raised from `DONTCARE` to `HIGHER`.

Interrupt spreading (Mali to CPU2, Bluetooth UART to CPU1) was applied and does
take effect, but was never shown to help on its own and is **not** shipped. It
remains available in `scripts/probe_ready.sh` if wanted.

### angrylion: closed, with a mechanism

Not viable in this fork, and now understood rather than merely observed.

An LLE RDP like angrylion needs an LLE RSP to feed it: the RSP interprets the
microcode and writes DP registers, which the RDP then rasterises. Testing both
pairings:

```
gfx=angrylion rsp=hle    survives 10s, 6% CPU, audio at exactly real-time silence, 0 frames
gfx=angrylion rsp=cxd4   SIGSEGV at 3s (exit code 139)
gfx=rice      rsp=hle    74% CPU, real work, 59 fps
```

With the HLE RSP, display lists are handed to `gfx.processDList()` -- which an LLE
RDP cannot consume -- so the game blocks forever waiting for the RDP. 6% CPU and
audio advancing at precisely real time is the signature of a game stuck in a wait
while the audio callback dutifully outputs silence. With CXD4, the correct
pairing, **RetroArch segfaults in three seconds.**

So the only RSP that could feed angrylion crashes, and the one that does not
crash cannot feed it. Even if the segfault were fixed, CXD4 is a cycle-accurate
interpreter with no chance of real time on a 1.2 GHz A7. Closed.

#### Retraction: the "forced LLE RSP" was never actually tested

Earlier in this log the forced-CXD4 hypothesis is recorded as *refuted* on the
grounds that patching it out changed nothing. That reasoning was wrong. The force
lives at the end of `core_settings_autoselect_rsp_plugin()`, which begins:

```c
if (rsp_var.value && strcmp(rsp_var.value, "auto") != 0)
    return;                     /* our .opt says "hle" -> returns here */
...
if (gfx_plugin == GFX_ANGRYLION)
    rsp_plugin = RSP_CXD4;      /* never reached */
```

Our `.opt` sets `rspplugin = "hle"`, so the function returns before the force.
The patch deleted dead code, which is exactly why results were byte-identical --
that identity should have been the tell, since two different RSP implementations
cannot plausibly produce the same counts. The hypothesis was untested, not
refuted; setting `rspplugin` explicitly is what finally exercised it, and it
segfaults.

### Fix: boot console rotation

The panel is mounted upside down, so the console prompt visible for the few
seconds before the launcher starts was upside down too. Note this was only ever
the **prompt** -- `quiet loglevel=4` on the command line suppresses the printk
flood, so there is no wall of boot text to rotate. Gil: *"boot text is now the
right way up (actually there is no text, there was never text, it is just the
prompt)"*.

Two changes:

```
linux-retrogaming.config : CONFIG_FRAMEBUFFER_CONSOLE_ROTATION=y
extlinux.conf            : ... fbcon=rotate:2 ...
```

Verified after reboot: `/proc/cmdline` carries `fbcon=rotate:2` and
`/sys/class/graphics/fbcon/rotate` reads `2`.

#### Why the command line rather than the panel's DT rotation property

The obvious approach is to teach the panel driver to call
`of_drm_get_panel_orientation()`, so the existing `rotation = <180>` in the DTS
sets a connector orientation hint that `drm_fb_helper` maps to `FB_ROTATE_UD`
and fbcon picks up automatically. The kernel plumbing for that is all present
(`drm_fb_helper.c` maps `DRM_MODE_ROTATE_180`, `fbcon.c` consumes
`fbcon_rotate_hint`).

It was rejected deliberately. `panel-waveshare-dsi-b.c` has **zero** calls to
`of_drm_get_panel_orientation`, and the DTS comment on that property is explicit
that nothing consumes it automatically -- every client compensates by itself
(RetroArch `video_rotation = "2"`, launcher `PANEL_ROTATION=180`). Exposing the
hint risks a client honouring it *on top of* its own correction and ending up
double-rotated: a regression on a working display, traded for a cosmetic gain.
`fbcon=rotate:2` touches the console and nothing else. Both the option and this
reasoning are commented in place.

#### Process notes

A kernel change needs `zImage` + `extlinux.conf` pushed to `/boot`, unlike
rootfs-only changes. The previous kernel is kept as `/boot/zImage.prev` with its
config alongside, so a bad kernel is recoverable from the serial console rather
than needing a card reflash.

The build printed `Clock skew detected. Your build may be incomplete.` -- the
usual WSL/`/mnt/c` timestamp mismatch. Outcome verified good anyway (option in
`.config`, fresh zImage, md5 match end to end), but it is the kind of warning
that becomes a mystery later if ignored.

Two verification attempts were wrong before one was right, both in the same
direction as the rest of this project -- measuring the wrong thing:

1. The first check connected as soon as SSH answered and captured the
   **pre-reboot** system (uptime 4323 s, old cmdline). It would have reported
   success from the old kernel had the cmdline not been printed.
2. The rewrite waited for uptime to drop, but started at uptime 22 s -- the
   reboot had already happened -- so it waited 7.5 minutes for a second one.

For a reboot check, record uptime *before* triggering it and require the later
reading to be lower, or compare kernel build stamps rather than liveness.

### Fix: network hot-plug and a Wi-Fi fallback path

Pulling the Ethernet left the board reachable only over the serial console. Two
separate gaps; the shipped `/etc/network/interfaces` already documented the
first as *"STILL MISSING: hot-plug ... a udev rule on SUBSYSTEM=="net",
ACTION=="add" is the proper fix and is not done yet."*

**1. Wired hot-plug.** `interfaces` brings eth0 up at boot with a backgrounded
`udhcpc`, which is right for boot time but does nothing for an adapter that
appears later. Swapping the USB-Ethernet adapter therefore left eth0 up but
unconfigured. Added `/etc/udev/rules.d/70-net-hotplug.rules` and
`/usr/sbin/net-hotplug`, which waits for carrier, replaces any stale client for
that interface rather than stacking them, and **backgrounds its own work** --
udev serialises `RUN+=` and kills slow rules, so the script must return at once.

Verified on hardware rather than assumed: `udevadm test` shows the rule matching
(`RUN '/usr/sbin/net-hotplug %k' ... :10`), and a live
`udevadm trigger --action=add --subsystem-match=net` replaced the running client
(pid 309 -> 1794) and kept the address, without dropping the SSH session it was
being tested over.

**2. Wi-Fi fallback.** `S49wifi` already does the right thing -- it brings wlan0
up at boot whenever `/etc/wpa_supplicant.conf` holds a network, and skips
entirely when it does not, so an unconfigured board still boots at full speed.
Once configured, wlan0 is simply up alongside eth0 and pulling the cable leaves
Wi-Fi. The only missing piece was credentials.

Those are deliberately **not** shipped in the image. Added
`/usr/sbin/wifi-setup`, which writes them to the running board only:

```
wifi-setup "MySSID" "mypassphrase"   configure and bring up now
wifi-setup --status                  state of wlan0 and eth0
wifi-setup --forget                  remove the saved network
```

It pipes through `wpa_passphrase`, so the file holds the hashed PSK rather than
the plaintext, and chmods the file 600.

Currently unconfigured on the board (`configured: no`), which is the correct
default -- it is Gil's call whether to put credentials on the device.

### Fix: Atari 800 level, measured instead of guessed

The shipped `audio_volume = "9.000000"` carried its own disclaimer: *"a starting
point, not a measurement: nobody has metered the core's output."* Now metered.

#### A general audio probe in RetroArch

The N64 probe lived inside the mupen64plus audio backend and was no use for any
other core. RetroArch applies `audio_volume` centrally, so a probe placed
immediately after `convert_float_to_s16` in `audio/audio_driver.c` -- the point
where clamping happens -- sees the true peak and any clipped samples for **every**
core. Gated behind `RETROBPI_AUDIO_PROBE=1` so it is inert unless asked for.

#### Measured: the old value was clipping, not under-driving

Unity gain, 70 s per title:

```
ARKANOID.ATR    native peak  5186   (15% of full scale)
Asteroids.atr   native peak  8908   (27%)
AIRWOLF.ATR     native peak 11738   (35%)   <- loudest
```

A 7 dB spread between titles, which is why "Atari is quiet" fits some games and
not others. Applying gain to the loudest:

```
 +7 dB -> AIRWOLF  80% FS
 +8 dB -> AIRWOLF  89% FS          <- shipped
 +9 dB -> AIRWOLF 100% FS, CLIPS   <- what was there
+12 dB -> Asteroids and AIRWOLF both clip hard
```

So the previous +9 dB was slightly **over**: loud titles were being clamped.
Shipped 8.0 dB, the largest value keeping the loudest measured title under the
clamp with margin. Cross-check: 5186 x 2.818 = 14614 predicted for ARKANOID at
+9 dB, against 14655 measured directly.

#### The loudness was analog all along

Digital gain is hard-capped here by clipping, so +8 dB cannot make Atari louder.
The actual headroom was in the analog stage, and in the launcher's own dial:

```
volume_apply():  idx = 63 - 40 + (pct * 40)/100
state.txt:       volume=55   ->  mixer index 45
```

The board had been sitting at **55% of the dial** -- 18 dB below full analog.
Setting `volume=100` (index 63, 0 dB) fixed the complaint immediately. Gil:
*"much better now"*.

Nothing clips digitally at that setting: Atari's loudest title reaches 89% FS,
NES peaked at 18612 (57%), SNES 12472 (38%).

#### Corrections

- Reported mid-session that +9 dB was "too conservative, 7 dB of headroom
  available". Wrong: that was measured on ARKANOID alone, the **quietest** of the
  three titles. On AIRWOLF the same gain clips. One title is not a level survey.
- A first run reported `peak=0` at every gain. The window was 25 s; an ATR takes
  about a minute to boot before making any sound, so it measured loading
  silence. Gil pushed back ("it does generate sound, just a bit low") and he was
  right. Same failure as the title-screen measurements elsewhere in this log:
  sampling before the thing being measured has started.
- A first attempt to write `state.txt` went to `/opt/roms/_data`; `DATA_DIR` in
  `launcher.c` is `/opt/roms/_system`. It silently did nothing. Stray directory
  removed.
- The on-board busybox `awk` has no math support, so `log()` in the reporting
  script produced blank columns -- compute dB on the host instead.

#### Note for later

The launcher's compiled-in default is still `g_volume = 80` (index 55). A device
with no `state.txt` therefore starts ~10 dB below full. Worth considering raising
it, balanced against a fresh unit booting at full blast.

### Fix: Atari 800 virtual keyboard -- a controller quirk, not a config error

Reported as "the Atari 800 virtual keyboard is not launching".

#### The controller never sends the thumb-stick codes

Captured with `evtest` on the running board:

```
click LEFT analog stick   -> BTN_TL2  (312)   the L2 TRIGGER code
click RIGHT analog stick  -> BTN_TR2  (313)   the R2 TRIGGER code
press X / O               -> BTN_SOUTH / BTN_EAST   (reference, capture verified)
BTN_THUMBL (317)          -> never emitted
BTN_THUMBR (318)          -> never emitted
```

`BTN_THUMBL`/`BTN_THUMBR` **are** advertised in the device's KEY bitmask
(`0x7fdb0000` at word 9 sets bits 317 and 318), so the driver claims them -- it
simply never sends them. The Atari core binds its virtual keyboard to
`RETRO_DEVICE_ID_JOYPAD_L3` and nothing else, so the toggle was unreachable.

Worse than inert: `platform.c` maps L2 to `AKEY_ESCAPE`, so every stick click was
quietly sending Escape into the emulator.

#### What identified it

Gil: *"BTW, the virtual keyboard works right in the ZX spectrum"*. The fuse core
binds its overlay to **SELECT** (`libretro.c:132`), which this pad sends normally.
Same controller, same overlay concept, different button, works. That turned "the
keyboard is broken" into "this one button is unreachable" -- a much smaller
problem, and it ruled out the 180 rotation as a cause in one sentence.

#### The fix

`0001-atari800-vkbd-on-R-as-well-as-L3.patch` accepts **R** in addition to L3.
R is genuinely free in this core: the input descriptors bind L (Option) but not
R, and `platform.c` records that R was deliberately left unbound once `AKEY_UI`
stopped doing anything. `BTN_TR` does arrive from this pad. L3 is retained so the
stock binding still works on hardware that reports stick clicks correctly.

A RetroArch input remap would have been the more "correct" mechanism and needs no
rebuild, but the `.rmp` key format could not be pinned down from the source in
reasonable time, and a core patch is certain, testable and already has
infrastructure here.

#### Three wrong turns

1. **Suspected my own volume hotkeys.** `input_volume_down_btn = "14"` looked like
   it might be stealing L3. It was not: the pad's autoconfig makes L3 button
   **11**, and 13/14 really are d-pad up/down as the config comment claimed.
   Checked rather than assumed, and the assumption was wrong.
2. **Two captures returned zero events** -- read at the time as "L3 produces
   nothing". Both were worthless: **busybox has no `timeout`**, so `evtest` never
   ran at all. `timeout: not found` was sitting in the log file the whole time.
   A third capture then reported "THUMBL: 1" which was `grep` matching evtest's
   *capability header*, not an event. Match `^Event:` lines, not the header.
3. **The capture instructions arrived after the window had closed**, because SSH
   buffers output -- Gil had no way to know when to press. Fixed by detaching the
   capture (`setsid nohup`) and collecting separately, the same pattern the audio
   watcher already used.

The diagnostic core option `atari800_vkbd_enabled` is shipped **disabled**; it was
set to `enabled` temporarily to prove the overlay could draw at all, which
separated "cannot render" from "button never arrives" in one test.

### Fix: ZX Spectrum joystick -- Kempston

Gil: *"In the ZX spectrum the joystick needs to be mapped to kempston, look at
the Lyra for reference"*. The Lyra had solved it, on the **same fuse commit**
(`69a44421`), and its log carried the whole diagnosis.

#### The config was already right

`config/fuse/fuse.cfg` already requested Kempston and was byte-identical to the
Lyra's:

```
input_libretro_device_p1 = "513"     /* RETRO_DEVICE_SUBCLASS(JOYPAD, 1) */
input_libretro_device_p2 = "513"
```

So this was never a configuration problem, which is exactly why it needed source
changes. In `retro_set_controller_port_device()`:

```c
switch (device) {
   case RETRO_DEVICE_CURSOR_JOYSTICK:
   case RETRO_DEVICE_KEMPSTON_JOYSTICK:
   ...
   default:                              /* plain JOYPAD lands here */
      input_devices[port] = device;      /* joystick_1_output NEVER set */
}
```

RetroArch calls this with `RETRO_DEVICE_JOYPAD` (value 1) after core init.
Plain JOYPAD matches none of the Spectrum joystick cases, so it falls through to
`default:`, which records the device but never assigns `joystick_1_output`. The
joystick is then silently dead regardless of what the frontend config asked for.

#### Two changes, both from the Lyra

`0002-fuse-kempston-joystick.patch`:

1. port 0 defaults to **Kempston** rather than Cursor (Cursor maps the stick to
   keyboard keys, which is not what Spectrum software expects)
2. plain `RETRO_DEVICE_JOYPAD` is **treated as Kempston**, so joystick input
   survives whatever the frontend sends -- this is the one that actually fixes it

Verified by `dirclean` + rebuild: both fuse patches re-apply from scratch, and
all three fixes are present in the freshly patched source.

#### Notes

- The keyboard overlay in this core is on **L1**, not SELECT. That is
  `0001-fuse-L1-toggles-keyboard-overlay.patch`, already carried here, which
  moved the toggle outside the device-type switch precisely because the device
  type was not being set correctly -- the same root cause as this joystick bug,
  found from the other side.
- The Lyra log also records that RetroArch override directories are
  case-sensitive and the core reports `library_name = "fuse"`, so the config must
  be at `config/fuse/fuse.cfg`. Ours is correct.
- **This project keeps patches in two places.** Package dirs
  (`package/retroarch/libretro-*/`) for the N64 and Atari cores, and
  `BR2_GLOBAL_PATCH_DIR` (`board/bpi-m2m/patches/`) for fuse, bluez5_utils, the
  kernel and mesa3d. Checking only the package dir led to a wrong "no patches for
  fuse" conclusion during this investigation. Check both.

### Published to GitHub

**https://github.com/giltal/RetroBPI-M2M** — public, GPL-2.0-or-later.

68 MB cloned. `firmware/` is gitignored in full: the sdcard image (2.6 GB), ROM
partition (2.0 GB), kernels, DTBs, u-boot, launcher binary and the staging
snapshots are all reproducible from source, and git stores a whole copy of every
changed binary. An initial `.gitignore` that only excluded `*.img` and `*.vfat`
still let 31.6 MB of stale binaries into the first commit.

`buildroot-external/package/retroarch/retroarch/retro-assets/` (94 MB) **is**
tracked, deliberately: `retroarch.mk:45` copies it into the target, so it is a
build input. That is most of the 68 MB.

Added alongside: `README.md`, `BUILDING.md` (host requirements, Buildroot 2026.02.3
setup, what the builder supplies themselves), `LICENSE`, `NOTICE`.

#### Two things worth remembering

**`.gitattributes` forces LF** for everything the Linux side consumes -- shell
scripts, patches, init scripts, C sources, configs. The host is Windows and git
was set to convert LF to CRLF on checkout, which would have handed anyone cloning
this a tree full of scripts that fail on the board in confusing ways. This project
has already lost time to stray CRLFs, including a patch that silently matched
nothing because the target file used them.

**GitHub's licence detector needs a verbatim match.** A scope note prepended to
`LICENSE` produced `licenseInfo: null`. Moving it to `NOTICE` and leaving `LICENSE`
as the unmodified GPL body -- copied from Buildroot's `COPYING`, not reconstructed
-- makes it register as GPL-2.0.

The root password `retrobpi` in the defconfig is public and permanent in history.
Raised before publishing; Gil's call was to leave it.

### N64 analog stick: verified end to end, and two errors of mine

Gil: *"steering feels like it is a digital joystick"*, and later *"the joystick
actually should function as a steering wheel and not as a D-Pad"*. He was right
that it should, and it does. The coarseness is the game.

#### The chain, measured at every stage

```
DualShock 3 -> evdev      123 distinct ABS_X values, range 0..255, centre 128
autoconfig                all 8 axis directions bound (l_x +-0, l_y +-1, r_x +-3, r_y +-4)
RetroArch -> core         52 distinct magnitude bins delivered (of 64 sampled)
core maths                output histogram matches input histogram exactly
core -> emulated N64      full +-80 range reached
```

`analog_dpad_mode` is unset, so the default `ANALOG_DPAD_NONE` applies and nothing
converts the stick to a d-pad. The core reads `RETRO_DEVICE_ANALOG` directly and
maps `ANALOG_LEFT` to the Control Stick, `ANALOG_RIGHT` to the C buttons.

#### Error 1: sensitivity 120 was actively harmful

Suggested raising `astick-sensitivity` to 120 before working out what the number
does. The core maps a full deflection as:

```c
radius *= 80.0 / ASTICK_MAX * (astick_sensitivity / 100.0);   /* ASTICK_MAX = 0x8000 */
```

The N64 stick range is +-80, and **nothing clamps the result**. At 100 a full push
maps to exactly 80; at 120 it produces 96. The outer ~17% of stick travel then does
nothing but hold full lock, and full lock arrives early -- precisely the edginess
being complained about. Reverted to 100.

The lever that actually shapes feel is the **deadzone**, and it works the opposite
way to intuition:

```c
radius = (radius - astick_deadzone) * (ASTICK_MAX / (ASTICK_MAX - astick_deadzone));
```

The remaining travel is rescaled back to full range, so a *larger* deadzone
compresses the whole response into less stick movement -- steeper, not gentler.
The 15% default spent the first 15% of throw doing nothing and covered everything
in the other 85%. Shipped **deadzone 5**, sensitivity 100.

#### Error 2: misreading the first histogram

The `X_AXIS` histogram showed 94% centre and, of the non-centre samples, 88% at
full lock with ~12% in between. This was called "the signature of quantisation".
**It is not.** It is a distribution over *time*: most of a lap is spent going
straight, then the stick is pushed to full lock and *held* through each corner,
which accumulates hundreds of samples at the extreme while each transition
contributes a handful.

The measurement that actually tests quantisation is the count of distinct values,
not the shape of the time distribution. Raw input showed **52 distinct magnitude
bins**, and the ~85 intermediate samples spanned roughly 50 of them -- nearly
every mid-range sample a different value. Textbook proportional input, passing
through quickly.

A histogram weighted by dwell time cannot distinguish "few intermediate values"
from "intermediate values held briefly". Count distinct values for that.

#### Shipped

```
parallel-n64-astick-sensitivity = "100"   /* 120 overdrives past the N64's +-80 */
parallel-n64-astick-deadzone    = "5"     /* down from 15; gentler curve near centre */
```

Instrumentation reverted; source pristine and the shipped core carries none of it.

### N64 frameskip: asked for, and it does not exist

The question was whether we could buy back the 640x480 visuals by skipping frames, the way
RetroESP32_P4 holds 60 FPS on 16-bit emulators. The answer is no, and the reason is structural
rather than a missing option.

- `parallel-n64-framerate` looks like the knob but is not one. It sets `frame_dupe`, which
  *duplicates* a frame by calling `video_cb(NULL, ...)` -- the frame is still fully rendered,
  it is just presented twice. That is why measuring it moved nothing: 814 vs 809 permille.
- rice has a `bSkipFrame`, and it is dead code. Two references exist in the whole tree:
  the declaration at `Config.h:219` and `ConfigGetParamBool(l_ConfigVideoRice, "SkipFrame")`
  at `RiceConfig.cpp:426`. Nothing ever reads it. Setting it would do exactly nothing.
- glide64 has no equivalent at all.
- RetroArch's own `fastforward_frameskip` only applies while fast-forward is engaged.

Why the ESP32-P4 technique does not transfer: on a 16-bit emulator the frame is a bitmap the
emulator hands over at the end of a scanline loop, so dropping the *presentation* of that
bitmap saves the blit and nothing else needs to know. On N64 the cost is 3D rasterisation
performed *inside the graphics plugin while it walks the display list*. By the time there is
a frame to skip, the work that made it expensive has already been paid for. Skipping it
properly would mean not walking the display list -- which desynchronises RDP state, because
later display lists depend on framebuffer contents earlier ones produced.

So 320x240 native stays the answer. The board is GPU-bound at 88% CPU with ~12% blocked on
Mali; there is no frame-pacing trick that recovers the difference.

### Near-miss: an instrumented core reached a built image

Worth recording because it is a *new variant* of the stale-`target/` trap, and the fifth time
that trap has bitten.

The sequence: the analog investigation patched the N64 core with a histogram probe. When it was
done I restored the source, verified it (`astick_probe refs left: 0`), and built an image. The
source was genuinely pristine. The **binary was not** -- `target/` is incremental, and nothing
in the restore triggered a rebuild of the `.so`. The image was built, copied to `firmware/`,
and announced as good. md5 `98fc4d3d...` contained a diagnostic core.

It was caught only because an ad-hoc push script happened to run `strings` on the core before
copying it to the board. That is luck, not process.

The lesson generalises past this repo: **verifying the source is not the same as verifying the
artifact.** Every previous instance of this trap was caught by checking a file's presence or
contents; none of them would have caught a stale binary built from correct source.

Fix, now in `buildroot-external/board/bpi-m2m/post-build.sh`: before an image is assembled,
every `.so` under `usr/lib/libretro/` is scanned for probe markers (`astick.log`, `glitch.log`,
`ra_audio.log`, `speed_permille`, `RETROBPI_AUDIO_PROBE`) and the build **fails** if any match.
Tested both directions -- an instrumented core exits 1 with a named error, clean cores exit 0.
The check costs a `strings` pass over ~20 files and runs on every image build, so it cannot be
forgotten the way an ad-hoc script can.

Good image after recovery: `c290f2ada21e687e137e2167c997ba3e`. Board N64 core `7018d969...`,
instrumentation markers 0.

### Fix: Bluetooth MAC -- the DT property was there all along, and inert

The adapter reported `AA:AA:AA:AA:AA:AA`, and every pairing logged against it:

    sony 0005:054C:0268.0001: BLUETOOTH HID v80.00 Joystick
        [Sony PLAYSTATION(R)3 Controller] on aa:aa:aa:aa:aa:aa

The obvious diagnosis -- "no address is configured" -- was wrong. The board DT
has carried `local-bd-address = [49 50 42 00 00 02]` since the panel patch, and
it is present in the running DTB:

    # od -An -tx1 /proc/device-tree/soc/serial@1c28400/bluetooth/local-bd-address
     49 50 42 00 00 02

So the property existed and was being ignored. The reason was in the same dmesg
I had already read past:

    Bluetooth: hci0: BCM: firmware Patch file not found, tried:
    Bluetooth: hci0: BCM: 'brcm/BCM43430A1.hcd'

`/lib/firmware/brcm/BCM43430A1.hcd` is present on the rootfs -- 30 KB of it. But
`BT_HCIUART` is built in, so hci_bcm probes at **0.97 s**, and the rootfs is not
mounted yet. (brcmfmac, which probes over SDIO much later, gets its firmware
fine at 5.0 s -- the contrast is the tell.) `request_firmware()` fails, and
`bcm_setup()` takes:

    if (!fw_load_done)
            return 0;

which sits **eleven lines above** the code that would have made the DT property
matter:

    if (hci_test_quirk(hu->hdev, HCI_QUIRK_INVALID_BDADDR))
            hci_set_quirk(hu->hdev, HCI_QUIRK_USE_BDADDR_PROPERTY);

Without the patchram, `btbcm_finalize()` never runs; without it,
`btbcm_check_bdaddr()` never runs; without that, `HCI_QUIRK_INVALID_BDADDR` is
never set. `hci_dev_init_sync()` gates the whole DT path on one of those two
quirks, so `hci_dev_get_bd_addr_from_property()` is never called and the chip
keeps the BCM43430A1 ROM default.

**The fix** is `0007-bluetooth-hci_bcm-honour-DT-bd-address-without-patchram.patch`:
set the quirk on the no-patchram path too, guarded by
`device_property_present()`. The guard is not optional -- setting the quirk with
no property behind it leaves `public_addr` as `BDADDR_ANY`, which keeps
`invalid_bdaddr` true and starts the controller `HCI_UNCONFIGURED`, i.e. no
Bluetooth at all. A wrong address beats no adapter.

Result on hardware, after booting the patched kernel:

    Controller 02:00:00:42:50:49 (public)   Powered: yes

**Why I tested with btmgmt first.** The kernel path calls
`hdev->set_bdaddr()`, and if that returns an error `hci_dev_init_sync()` returns
non-zero and the controller disappears entirely. So the open question --
does the vendor `Write_BD_ADDR` (0xFC01) work on *unpatched* ROM firmware? --
had to be answered before touching the kernel, because getting it wrong costs
Bluetooth rather than costing a wrong address. `btmgmt public-addr` exercises
the same `btbcm_set_bdaddr()` from userspace, where failure is free. It worked,
which made the kernel patch safe to write.

`btmgmt` is not installed: bluez builds it as a `noinst_PROGRAM`
(`Makefile.tools:505`), so it exists in the build tree and never reaches the
target. Copy it from
`output/build/bluez5_utils-5.79/tools/btmgmt` when needed.

That test did knock Bluetooth out on the live board: setting the address while
stopping and restarting bluetoothd around it left the controller stuck in
`HCI_CONFIG` -- `hci0` still in sysfs, but mgmt answering "Invalid Index". The
address is not persistent (it is re-applied at every adapter open), so a reboot
restored everything. Worth remembering: `set_public_address` queues a
`power_on` and re-adds the mgmt index, and racing bluetoothd against that
sequence loses.

**Consequence for pairing:** the DS3 stores the HOST address and will only
connect back to it. Changing the adapter address invalidates the existing
pairing -- the pad must be cable-paired once more. BlueZ's pairing DB is keyed
by adapter address too, so `/var/lib/bluetooth/AA:AA:AA:AA:AA:AA/` is now dead
and a fresh `02:00:00:42:50:49/` has taken over.

**Re-paired and confirmed on hardware.** Cable pairing over USB, with the auto
agent doing its job:

    /var/lib/bluetooth/02:00:00:42:50:49/A0:5A:5E:9D:2C:1D   <- link key, new adapter
    sony ...: BLUETOOTH HID v80.00 Joystick
        [Sony PLAYSTATION(R)3 Controller] on 02:00:00:42:50:49

Both failure signatures checked and clear: zero `sixaxis ... failed` lines in
dmesg, zero "Authentication attempt without agent" in the agent log. The stale
`/var/lib/bluetooth/AA:AA:AA:AA:AA:AA/` tree was then removed, guarded by a
check that the new adapter actually holds a link key first.

**USB port note, learned the annoying way.** Ethernet on this board is a USB
dongle (RTL8153) on the USB-A port, and that is the same port a DS3 needs for
cable pairing. Pairing therefore takes the network -- and SSH -- down with it:

    usb1  EHCI  <- USB-A, occupied by "USB 10/100/1000 LAN"
    usb2  MUSB  <- micro-USB OTG, running in HOST mode, free
    usb3  OHCI  <- companion controller, same physical port as usb1

The micro-USB OTG port is a host and is free, so with an OTG adapter the pad can
be cable-paired without touching Ethernet. Worth remembering before starting any
remote watcher during a pairing: the board will simply vanish mid-operation
otherwise, which looks like a failure and is not one.

**After a reflash the pad needs one more cable pair.** The adapter address is
baked into the DT, so it stays 02:00:00:42:50:49 and the address stored in the
pad stays valid -- but the link keys live on the rootfs and a flash wipes them.

**Still fixed, not per-board.** Every unit built from this image gets the same
address. Making it per-board needs the bootloader to write the property (the
kernel comment literally says "Allow the bootloader to set a valid address
through the device tree"), or a userspace pass with btmgmt before bluetoothd
starts. The SoC SID is available as the `Serial` line in `/proc/cpuinfo`
(`165541530706808b` on this unit) -- note that the DTS comment previously
pointed at `/sys/bus/soc/devices/soc0/serial_number`, which does not exist on
this board; that has been corrected.

To read the address on the board, with no extra tools:

    printf 'show\nquit\n' | bluetoothctl

Note `/sys/class/bluetooth/hci0/address` does not exist on this kernel, and
`hciconfig` is not built.

## 2026-08-27 — Boot time: a 10.3 s self-inflicted regression, and the floor underneath it

Boot had drifted from the 4.92 s recorded earlier to roughly 12 s. The cause was
mine, added in the network-hotplug session.

### The regression: udev waits for a pipe, not for a process

`/run/boottiming` (the rcS profiler, which is why it ships) attributed it in one
read -- every script under 0.2 s except one:

```
S10udevd   10.55 s   (5.22 -> 15.77)
```

Timing the three steps separately: `udevadm trigger` 0.19 s combined, and
`udevadm settle` **10.33 s**. Almost nothing appeared in the kernel log during
that window, so udev was blocked in a rule, not on hardware.

The rule was `70-net-hotplug.rules` -> `/usr/sbin/net-hotplug`, whose carrier
wait is `while [ $i -lt 10 ]; do ... sleep 1; done`. Ten iterations, ten seconds.
The script *did* background that work and exit immediately, and its comment even
said "udev serialises RUN+= and kills slow rules, so the work is backgrounded"
-- which was the wrong mental model:

**udev does not wait for the RUN program to exit. It waits for the stdout/stderr
pipe it handed that program to reach EOF.** A `( ... ) &` subshell inherits those
descriptors and holds the pipe open for its whole lifetime. Redirecting the inner
`udhcpc` was not enough; the subshell itself had to give up all three
descriptors. Fix: `setsid /bin/sh -c '...' </dev/null >/dev/null 2>&1 &`.

Isolated on the board, reproducing exactly what udev does (`| cat` cannot finish
until every holder of the write end is gone):

```
bad.sh  ( sleep 3 ) &                                  pipe closed after 3.02 s
good.sh setsid sh -c 'sleep 3' </dev/null >/dev/null &  pipe closed after 0.01 s
```

Result: settle 10.33 -> 0.41 s, S10udevd 10.55 -> 0.64 s, and DHCP still works.

### Then four hypotheses, three of them wrong

`S01syslogd` was next at 1.63-1.71 s, against 0.02 s when restarted by hand.

- **Entropy.** Plausible: this project already knew udevd, the BT agent and
  dropbear all block on `crng init`. Rebuilt the `seed-credit` tool deleted in an
  earlier session; it reproduced its old result exactly (crng 3.5 s -> 2.1 s,
  reliably). syslogd still took 1.63 s with the CRNG ready at 2.06 s. **Refuted.**
- **Cold page cache.** `drop_caches` then restart: 0.03 s. **Refuted.**
- **CPU frequency** (S05powercap sets `performance`, and it runs *after* S01).
  Forced via `scaling_max_freq`: 0.11 s at 120 MHz, 0.02 s at 1.2 GHz. Not 1.6 s.
  **Refuted.** (First attempt wrote `powersave` to `scaling_governor` -- not an
  available governor here, so the write silently failed and the "test" ran at
  1.2 GHz. A test that cannot fail proves nothing.)
- **Instrumented inside the script instead of guessing again.** `start()`'s body
  took 0.10 s; **0.83 s elapsed before its first line ran**. The cost was the
  script failing to get going -- because `S01seedrng` had just backgrounded
  `seedrng`, which regenerates the next seed and `fsync()`s it to the SD card.

Splitting those halves -- credit synchronously (`seed-credit`), regenerate later
(`S51seedrefresh`) -- moved rcS end from 5.33 s to 3.80 s.

### The floor: the boot is I/O-bound

Time-to-UI refused to move, across four different configurations:

```
                                   launch   rcS end   ready
baseline (udev fixed)                4.72      5.33    5.48
+ seed-credit                        4.86      5.48    5.62
+ regeneration deferred to S51       3.16      3.80    5.46
+ brcmfmac deferred behind launcher  3.18      3.93    5.46
syslogd/klogd moved behind launcher  4.14      4.80    4.93
```

Init finishes 1.5 s earlier and far more consistently, but `ready` sits at ~5.46 s
no matter what. The launcher simply absorbs the wait -- its self-reported init
stretched from 740 ms to 2498 ms as it was moved earlier. Measured directly:

```
launcher init, idle + warm cache :  317 ms
launcher init, idle + cold cache :  603 ms
launcher init, during boot       : 2498 ms
```

It needs ~600 ms of its own; the rest is contention for the card. **Reordering
redistributes I/O, it does not reduce it**, which is why entropy, script order and
the Wi-Fi driver all landed on the same number. Further gains need less total I/O
or faster reads, not a different order.

The brcmfmac deferral was reverted: it worked (firmware request moved 3.06 ->
3.78 s) and bought nothing, so it was not worth the complexity of blacklisting a
driver. The syslogd/klogd reorder was also dropped -- its apparent 0.55 s win was
confounded (crng averaged 3.52 s in the baseline runs vs 3.21 s in its own), and
it costs early-boot logging.

Raising SD readahead to 1024k -- the one lever that attacks total I/O rather than
its order -- made things **worse**, consistently across all four runs:

```
                 udev   launch   rcS end   ready
default 128k     0.63     3.16      3.80    5.46
readahead 1024k  0.73     3.45      4.17    5.83
```

Boot reads are scattered, not sequential, so a larger readahead window mostly
fetches pages nobody wants and spends card bandwidth doing it. Reverted.

### Where it landed

```
before this session : ~12 s   (regressed from 4.92 s by the udev rule)
after               : ~5.5 s to UI, rcS complete at 3.8 s
```

Kept: the net-hotplug fd fix (worth 10.3 s), `seed-credit`, and
`S51seedrefresh`. Rejected with measurements: script reordering, deferring
brcmfmac, SD readahead.

**What would actually move the number now** is reducing what the boot reads --
the launcher pulls in SDL2, SDL2_image, SDL2_ttf, mesa and fonts, and needs
~600 ms of I/O even on an idle system with a cold cache. That is the remaining
target, not the init sequence.

### Mali overclock: measured, and it does not help

Asked for directly: overclock the Mali-400 to 600 MHz to buy back 640x480. The
answer is no, on two independent grounds.

**First, the GPU only limits below 384 MHz.** Pinning devfreq to each stock OPP
and measuring the same 900-frame gameplay window (Mario Kart 64, 640x480, rice):

```
144 MHz -> 31.0 fps (52%)
240 MHz -> 42.5 fps (71%)
384 MHz -> 50.9 fps (85%)
```

That scales strongly, so 640x480 really is GPU-bound at stock -- the first direct
evidence for a claim this project had been carrying on inference. Fitting
`t = a + b/f` gave `a ~= 12.1 ms` of clock-independent work and `b ~= 2906` MHz*ms
of GPU work, predicting 41.3 fps at 240 against 42.5 measured. On that basis the
extrapolation said 480 MHz -> 92% and 600 MHz -> 98%.

**The extrapolation was wrong.** With OPPs added and re-measured:

```
384 MHz -> 53.7 fps (89%)
480 MHz -> 54.5 fps (91%)
528 MHz -> 53.7 fps (89%)
```

Flat, with the three deltas agreeing to within 1.5%. Raising the GPU core clock
37% buys ~1%. The fit was extrapolating past a wall it could not see from below
it: core clock does not buy memory bandwidth, and on 512 MB of DDR3 shared with
four CPUs and the display controller, bandwidth is what binds above ~384 MHz.
Strong scaling underneath a bottleneck says nothing about what lies above it.
The upper-bound caveat recorded at the time was right in direction and far too
generous in size.

**Second, 600 MHz does not run at all.** ~1970 lima faults --
`pp0/pp1 task error int_state=0 status=5`, `gp bus stop timeout` -- and a hung
RetroArch. 432, 480 and 528 each ran clean, so the functional ceiling sits
between 528 and 600, but since none of them are faster that ceiling is useless.
There is nothing to tune with: the A33 `mali_opp_table` has no `opp-microvolt`
and lima reports `no regulator (mali) found`, so it is clock-only.

The OPPs are kept as the record of a measured negative result; `S05powercap`
pins the cap at the stock 384 MHz.

#### A measurement that had to be thrown away

The first escalation run reported 384 MHz at 63.0 fps -- against 50.9 fps for the
same configuration an hour earlier -- and 432 MHz coming out *slower* than 384.
Both impossible. The cause was shortening the window from 900 to 600 frames to
save time: `delta` is the difference of two ~90-100 s runs, so ordinary startup
and I/O variance swamps a 10 s window. Restoring the 900-frame window produced
the consistent numbers above. The shorter window was not a smaller measurement,
it was a different one.

#### Two bugs found on the way

**The launcher was unstoppable.** `S12launcher stop()` ran `rm -f "$PIDFILE"`
unconditionally, even when the kill failed. Once that happened the launcher kept
running with no pidfile, every later `stop` failed, and it held DRM master
forever -- so every RetroArch launch died with `[KMS]: Error when switching mode`
/ `Cannot open video driver`, which reads like a graphics fault and is really a
stale process. `stop()` now escalates TERM -> KILL by name and only removes the
pidfile once `pidof` confirms the process is gone.

That bug also produced a whole sweep of fabricated numbers -- every run failed in
~1.06 s and the script reported **90000 fps, 150000%**. The benchmarks now abort
if the launcher survives, and reject any run of thousands of frames that finishes
implausibly fast. Same lesson as the vacuous `strings` zeros: a failed command is
not a measurement.

**The board has no thermal protection.** `/sys/class/thermal` held no
`thermal_zone*` at all, so SoC temperature could not even be read, let alone
throttled on, on a passively cooled console that runs N64 at ~100% CPU. The DTS
was never at fault: `sun8i-a33.dtsi` already declares `ths@1c25000` and a full
`cpu-thermal` zone with trip points and a cooling map onto all four CPUs, and
both are present in the live DTB. The sensor driver simply never probed.

The obvious fix was the wrong one. `sun8i_thermal.c` looks like the match and is
already built in, but its compatible list is a83t/h3/r40/a64/a100/h5/h6/d1/h616
-- no A33. On A33 the sensor is part of the GPADC block and is claimed by
`drivers/iio/adc/sun4i-gpadc-iio.c`, which is what the node's `#io-channel-cells`
property was signalling. `CONFIG_SUN4I_GPADC=y` is the fix.

Worth recording how the wrong answer nearly shipped: the first search grepped for
`SUN8I_THS`, the symbol is `SUN8I_THERMAL`, so it reported "not enabled" for
something that was already `=y`. The tell was the rebuilt zImage having an
identical md5 -- adding a driver must change the binary. The build script now
fails outright if the md5 does not change.

### Current state (2026-08-26)

`firmware/sdcard.img` md5 `339c0641bebefd3b7cca0cde1060ea43`. Board verified
byte-identical to this image across all 27 checked files plus kernel and DTB, so
SSH pushes and a fresh flash produce the same system.

**Working and confirmed on hardware:** 21 cores / 15 systems; display rotated 180
everywhere including RetroArch's menu, OSD and now the boot console; touch in the
search keyboard; jump-to-letter with overlay; menu position remembered at both
levels; PlayStation (user supplies BIOS); GBA at full speed on gpSP; Atari
800/5200 with a working virtual keyboard; ZX Spectrum with Kempston joystick and
L1 keyboard overlay; in-game volume hotkeys; speaker via the PH9 amp; boot ~4.9 s;
Bluetooth on a real address (02:00:00:42:50:49) rather than the BCM ROM default.

**N64 is solved.** Native 320x240 with rice, `alsathread`, `performance`
governor, and three core audio patches. 998/1000 emulation speed, no dropouts, no
clipping.

**Patches are carried in TWO places** -- check both before concluding something is
unpatched:
- `buildroot-external/package/retroarch/libretro-*/` -- N64 (3), Atari 800 (1)
- `buildroot-external/board/bpi-m2m/patches/` (BR2_GLOBAL_PATCH_DIR) -- fuse (2),
  bluez5_utils (1), linux (7), mesa3d (1)

Every patch above has been verified to re-apply after a `dirclean`.

### Next

Nothing here is blocking; the device is usable as it stands.

**Fixes**

1. ~~Boot console rotation~~ -- **DONE 2026-08-26**, see the fix section above.
   `CONFIG_FRAMEBUFFER_CONSOLE_ROTATION=y` plus `fbcon=rotate:2`. It was only ever
   the prompt, not a text flood, because `quiet loglevel=4` suppresses printk.
2. **BCM43430A1 patchram fails**, leaving the bogus `AA:AA:AA:AA:AA:AA` BT
   address. Pairing works regardless, so this is tidiness rather than function.
3. ~~Hot-plug networking~~ -- **DONE 2026-08-26**, see the fix section above.
   udev rule for wired hot-plug (tested live), plus `wifi-setup` for the Wi-Fi
   fallback. Wi-Fi is still **unconfigured by choice** -- run
   `wifi-setup "SSID" "pass"` on the board to enable it; credentials are not
   shipped in the image. Note the board's address moved from 192.168.1.50 to
   10.100.102.76 mid-project; `scripts/board_up.sh` carries the current value.
4. ~~Atari 800 level~~ -- **DONE 2026-08-26**, see the fix section above.
   Measured, not guessed: +8 dB (the old +9 dB clipped the loudest title), and
   the real fix for loudness was the analog dial, which was at 55%.

5. ~~ZX Spectrum joystick~~ -- **DONE 2026-08-26**. Kempston, ported from the
   Lyra. The `.cfg` had always requested it; the core silently discarded plain
   `RETRO_DEVICE_JOYPAD`.
6. ~~Atari 800 virtual keyboard~~ -- **DONE 2026-08-26**. Toggled with **R1**;
   this pad never emits L3.

**Upgrades**

7. **Touch is search-keyboard only, by design.** Extending it to scrolling the ROM
   list or tapping a system is new launcher work: `touch_poll()` would need
   calling from the main loop.
6. **Interrupt spreading** (Mali to CPU2, Bluetooth UART to CPU1) is implemented
   in `scripts/probe_ready.sh` and does take effect, but was never shown to help
   on its own and is deliberately **not** shipped. Worth re-measuring against
   `speed_permille` now that N64 runs at full speed -- it may buy headroom for
   raising the resolution again.
7. **N64 at 640x480** needs a faster GPU, not more CPU. The emulator blocks ~12%
   of the time waiting on the Mali (88% CPU, not 100%). If any render-side saving
   can be found, resolution is what to spend it on.
8. **Unattended smoke test** with `inject-input`, so a build can be validated
   without a human driving the pad.

**Tooling worth keeping**

- `scripts/audio_watch.sh` -- ALSA margin watcher, ~700 Hz, fork-free, 0% CPU.
- `scripts/analyse_audio.py` -- pure-Python FFT analysis of a raw capture (no
  numpy on this host).
- `scripts/audio_capture.sh` -- captures the exact s16 stream from the core.
- `scripts/speed_ab_board.sh` -- automated A/B against emulation speed using the
  attract-mode demo for realistic load.
- `scripts/instrument_*.py` -- all patch from a pristine `.orig`, so they can be
  re-applied and reverted cleanly.

### Historical bring-up steps (all completed)

#### Bring-up round (completed)

1. ~~Fit R104/R105~~ — not needed; console works on CON1 P08/P10 as shipped.
2. Console on **CON1 P08 (TX) / P10 (RX)** @ 115200. Read the actual failure before changing
   anything about the image — two variables at once will waste the reading.
3. Prepared but **not yet applied**, for after the first reading:
   - replace `fdtdir /boot` with an explicit `fdt /boot/sun8i-r16-bananapi-m2m.dtb` (U-Boot's
     `$fdtfile` may carry an `allwinner/` prefix our flat `/boot` does not have)
   - add `earlycon=uart,mmio32,0x01c28000` so the earliest kernel output is visible

#### Panel bring-up round (completed)

1. Flash `sdcard.img`, confirm serial console on CON3 @ 115200.
   **If UART0 is silent, try UART2** — the vendor docs note an SD/UART0 pin overlap.
2. Boot with the stock DTB first (`sun8i-r16-bananapi-m2m.dtb`), confirm userspace.
3. Wire the panel (5 V external supply, 3V3 ear from CON1-P01/P17, four J6 flying wires),
   switch to `sun8i-a33-bananapi-m2m-ek79007.dtb`.
4. `i2cdetect -y 0` should show the GT911 at 0x5d or 0x14 — that validates the cable's I2C pair,
   3V3 and ground before any DSI is involved.
5. `modetest -M sun4i-drm`. With `DRM_FBDEV_EMULATION` + `FRAMEBUFFER_CONSOLE` the kernel log
   should appear on the LCD — the cheapest "panel is alive" signal on a board with no HDMI.
6. Then RetroArch + cores, then the fast-boot pass.

### Open risks (panel bring-up -- all since resolved on hardware)

The panel, touch and rotation have all been working for some time; these are kept
as a record of what was uncertain at the time, not as live concerns.

- `mode_flags` for the EK79007 is a genuine guess (Espressif drives DPI and never exposes the DSI
  video-mode variant). Start plain `MIPI_DSI_MODE_VIDEO`; try `SYNC_PULSE`, then burst.
- The four J6 flying-wire GPIOs (PH6/PB2/PH7/PH1) are unused in the base DTS and `pio` is an
  interrupt-controller, but the pin-mux still wants checking against the R16/A33 manual.
- J6 pin numbering could not be extracted reliably from the schematic PDF — read the silkscreen.
