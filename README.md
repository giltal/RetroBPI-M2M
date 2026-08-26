# RetroBPI M2M

Retro gaming console firmware for the **Banana Pi BPI-M2 Magic** — Allwinner
R16/A33, four Cortex-A7 at 1.2 GHz, Mali-400 MP2, 512 MB DDR3, 8 GB eMMC.

Buildroot 2026.02.3 and mainline Linux 6.18.8. Boots to a custom DRM/KMS
launcher in about five seconds, with 21 emulator cores across 15 systems.

Ported from the [LyraZeroW SuperRetroPack](https://github.com/giltal) project,
which targeted a Rockchip RK3506B. The headline gain over that board is **N64**,
which the Lyra could not run at all.

---

## What works

| | |
|---|---|
| **Systems** | NES, SNES, Game Boy / Color / Advance, Genesis, Master System, Game Gear, PC Engine, SuperGrafx, Atari 2600 / 7800 / 800 / 5200, ZX Spectrum, Neo Geo, Doom, PlayStation, **Nintendo 64** |
| **Display** | Waveshare 5" DSI panel, 800×480, rotated 180° throughout — kernel, launcher, RetroArch menu and OSD, and the boot console |
| **Input** | DualShock 3 over Bluetooth; capacitive touch for the search keyboard |
| **Audio** | Speaker via an amplifier gated on PH9, in-game volume hotkeys, per-core level correction |
| **Launcher** | Jump-to-letter, favourites, recents, save-state slots, remembered position at both the system and ROM level |

There is **no HDMI on this board**. All display bring-up was done blind against a
serial console.

## The N64 problem, and what it turned out to be

N64 ran, but the audio was subtly dirty. Four rounds of instrumentation reported
the audio pipeline perfectly healthy: ALSA buffer margin rock steady at 96 ms,
zero underruns, zero sample discontinuities, no aliasing.

All of that was true, and all of it was irrelevant. RetroArch's dynamic rate
control **stretches audio to hold the buffer at its target**, so it is designed
to keep exactly those metrics looking good while the emulator falls behind. The
measurement that mattered was one nobody had taken — audio-seconds produced
against wall-seconds elapsed:

```
audio produced : 161.2 s
wall clock     : 184.4 s
ratio          : 0.874        <- emulator running at 87% of real time
```

The dirt was the stretch ratio itself modulating, second to second, between 0.85
and 1.10. The emulator was **GPU-bound**, not CPU-bound — it blocked ~12% of the
time waiting on the Mali (88% CPU, never 100%). Rendering at the N64's native
320×240 instead of 640×480 restored 998/1000 real-time speed.

Three genuine core-side audio defects were found and fixed on the way, none of
which was the cause: sinc-resampler overshoot clipping the output, a hardcoded
44100 Hz target against a 48000 Hz codec (two resampling stages where one would
do), and a resampler running at `RESAMPLER_QUALITY_DONTCARE`.

The general lesson, which cost several sessions: **be wary of any metric a
control loop exists to stabilise.** Measure what the loop sacrifices, not what it
protects.

## Building

See **[BUILDING.md](BUILDING.md)**. In short: Linux or WSL2, ~20 GB of disk,
several hours, and Buildroot 2026.02.3 cloned separately. You supply your own
ROMs and PlayStation BIOS — neither is distributed here.

## Repository layout

```
buildroot-external/   BR2_EXTERNAL: defconfig, package recipes, board files, patches
kernel/               panel drivers and our device tree sources
launcher/             the launcher (C, SDL2 on DRM/KMS)
scripts/              build, deploy and diagnostic tooling
docs/                 panel port, wiring, flashing, cable bring-up
DevelopmentLog.md     ~3600 lines of how it was built, including the wrong turns
```

Patches live in **two** places — `buildroot-external/package/retroarch/libretro-*/`
for the N64 and Atari cores, and `buildroot-external/board/bpi-m2m/patches/`
(`BR2_GLOBAL_PATCH_DIR`) for fuse, bluez5_utils, the kernel and mesa3d. Every one
has been verified to re-apply after a `dirclean`.

## A note on the development log

`DevelopmentLog.md` deliberately records the wrong turns alongside the fixes —
measurements taken against the title screen instead of gameplay, a detector that
could not fail, a "refuted" hypothesis that was never actually tested because the
code path was unreachable. Those entries are frequently more useful than the
fixes, because the same mistakes are easy to repeat.

## Licence

GPL-2.0-or-later. See [LICENSE](LICENSE).

This covers the work original to this repository. Buildroot, Linux, U-Boot,
RetroArch and the libretro cores are fetched from their own upstreams at pinned
revisions and remain under their own licences. No ROMs or BIOS images are
distributed here.
