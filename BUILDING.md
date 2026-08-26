# Building RetroBPI_M2M

## What this repo is, and is not

The repo is **~68 MB** cloned. It contains sources, patches, configs and docs.
It does **not** contain build outputs — `firmware/` is gitignored, because the
sdcard image alone is 2.6 GB and every rebuild produces a different binary.

So a clone gives you the recipe, not the cake. Expect to build.

## Host requirements

| | |
|---|---|
| OS | Linux, or Windows with WSL2 (Ubuntu 22.04 is what this was developed on) |
| Disk | **~20 GB** for the build tree, plus ~800 MB of downloaded sources |
| RAM | 8 GB is comfortable; Buildroot parallelises hard |
| Time | Several hours for a first build — it compiles a toolchain, a kernel, U-Boot, RetroArch and 21 emulator cores from source |
| Network | Required. Buildroot downloads ~760 MB on the first build |

Buildroot's own prerequisites (Debian/Ubuntu):

```bash
sudo apt-get install -y build-essential git bc bison flex libssl-dev \
    libncurses-dev python3 python3-dev unzip rsync wget cpio file \
    gawk gettext texinfo help2man libtool-bin pkg-config
```

## Getting the sources

Buildroot is **not** vendored here — clone it separately, at the version this
was built against:

```bash
mkdir -p ~/bpi && cd ~/bpi
git clone --depth 1 --branch 2026.02.3 https://gitlab.com/buildroot.org/buildroot.git
git clone https://github.com/<you>/RetroBPI_M2M.git
```

The layout matters: the launcher package builds from
`$(BR2_EXTERNAL_RETROBPI_PATH)/../launcher`, so `buildroot-external/` and
`launcher/` must stay siblings inside the repo. Don't reorganise them.

## Building

```bash
cd ~/bpi/buildroot
BR2_DL_DIR=~/bpi/dl make BR2_EXTERNAL=/path/to/RetroBPI_M2M/buildroot-external \
    O=~/bpi/output bpi_m2m_retro_defconfig
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output -j$(nproc)
```

Result: `~/bpi/output/images/sdcard.img`, ready to `dd` to a card. See
`docs/flashing.md`.

Convenience wrappers live in `scripts/` (`rebuild_image.sh`, `rebuild_n64.sh`,
`rebuild_kernel.sh`); they assume the `~/bpi` layout above.

## What you must supply yourself

- **ROMs.** Not distributed here. They live on the `roms.vfat` partition.
- **PlayStation BIOS** (`SCPH1001.BIN`). Copyrighted Sony code, deliberately not
  shipped. PSX will not run without it. Place it in `_system/bios/` on the ROM
  partition.
- **Wi-Fi credentials**, if you want Wi-Fi. Run `wifi-setup "SSID" "pass"` on the
  running board — credentials are not baked into the image by design.

## Hardware

This targets one specific build: a Banana Pi BPI-M2 Magic with a **Waveshare 5"
DSI panel (B)** mounted **upside down** (hence the 180° rotation throughout), a
speaker driven from HPL/HPR through an amplifier enabled on **PH9**, and a
DualShock 3 over Bluetooth.

Different panel or orientation? Start at `rotation = <180>` in
`kernel/sun8i-a33-bananapi-m2m-ws5b.dts` and follow the references in the comment
there. `docs/` covers the panel port, wiring and cable bring-up.

**There is no HDMI on this board.** Keep a serial console on CON3
(GND / UART0-RX / UART0-TX, 115200 8N1) attached during bring-up. It has been the
only way in on several occasions.

## Things that will bite you

- **`target/` is incremental.** Deleting a file from the rootfs overlay does not
  remove it from the image; the previously-installed copy survives. This has
  produced four wrong images so far. `board/bpi-m2m/post-build.sh` deletes known
  stale paths and hard-fails on a few invariants.
- **Patches live in two places.** `buildroot-external/package/retroarch/libretro-*/`
  for the N64 and Atari cores, and `board/bpi-m2m/patches/` (BR2_GLOBAL_PATCH_DIR)
  for fuse, bluez5_utils, the kernel and mesa3d. Check both before concluding
  something is unpatched.
- **Line endings.** `.gitattributes` forces LF for everything the Linux side
  consumes. If you bypass it, a CRLF in a shell script, patch or init script
  fails in ways that look like an unrelated bug.
- **Verify a change reached the image**, not just the source. The build can
  succeed while shipping the old file.

## Where the history is

`DevelopmentLog.md` (~3600 lines) records how each subsystem was brought up,
including the measurements and the wrong turns. The wrong turns are often the
more useful half — several conclusions in this project were confidently wrong
before they were right, and the log says which and why.
