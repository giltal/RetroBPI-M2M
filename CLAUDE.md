# RetroBPI_M2M — Project Instructions

## What This Is

Retro gaming console firmware for the **Banana Pi BPI-M2 Magic** (Allwinner R16/A33, 4× Cortex-A7,
Mali-400 MP2, 512 MB DDR3, 8 GB eMMC). Port of the **LyraZeroW SuperRetroPack** project.

- **Read `Context.md` first** — hardware, CN2 DSI pinout, mainline-vs-BSP analysis, and the plan.
- **Reference project:** `C:\LuckFox_Projects\LyraZeroW_SuperRetroPack` — its `CLAUDE.md`,
  `Context.md` and `DevelopmentLog.md` describe the launcher, RetroArch patches and core set
  that we are porting. Reuse the launcher and RetroArch work; **do not** port the RGA2 code
  (Rockchip-only).

## Hard constraints

- **Vendor images are kernel 3.4.39 only.** They have no DRM/KMS, so the launcher and RetroArch's
  `drm` driver cannot run on them. The real target is **mainline Linux**.
- **No HDMI on this board.** Display bring-up is blind — always have the serial console on CON3
  (GND / UART0-RX / UART0-TX, 115200 8N1) attached. If UART0 is silent, try UART2.
- Mainline `sun8i-r16-bananapi-m2m.dts` has **no display nodes**. The DSI/DPHY/TCON hardware nodes
  exist in `sun8i-a33.dtsi`; the board-level panel/backlight/touch nodes are ours to write.

## Development Environment

- **Host OS:** Windows + WSL2 (Ubuntu 22.04) for cross-compilation — same setup as the Lyra project.
- **WSL command pattern:** `wsl bash -c "..."` from PowerShell (NOT `wsl -e`, causes path mangling).

## Build

Buildroot 2026.02.3 LTS, cloned to `~/bpi/buildroot` in WSL, built out-of-tree to `~/bpi/output`
with our BR2_EXTERNAL living in the project folder.

```bash
wsl bash -c "cd ~/bpi/buildroot && BR2_DL_DIR=~/bpi/dl make BR2_EXTERNAL=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external O=~/bpi/output bpi_m2m_retro_defconfig"
wsl bash -c "cd ~/bpi/buildroot && BR2_DL_DIR=~/bpi/dl make O=~/bpi/output -j$(nproc)"
```

Result: `~/bpi/output/images/sdcard.img` — dd straight to the card.

**WSL quoting:** invoke via the PowerShell tool, and put anything non-trivial in a script file.
`wsl bash -c '...'` from git-bash mangles `$vars` and pipes, and `/mnt/c` paths get MSYS-rewritten.

**Backslashes get eaten one level** when writing script files through heredocs here.
This matters whenever a generated file must itself contain a backslash — e.g. emitting
C source with a \\n escape inside a string literal, or building a regex.
Symptoms: a \\n intended as two characters turns into a real line break, and
exact-match string replacements mysteriously find zero occurrences. Build such strings
with `chr(92)` instead of typing a backslash, and prefer line-number splicing over
exact-match replacement when editing generated sources. Check line endings too —
strip CR after writing any shell script.

## Key Paths

```
C:\BananaPi_Projects\RetroBPI_M2M      # project root
  Context.md                            # hardware + plan (read first)
  DevelopmentLog.md                     # session history — read the last entry
  docs/                                 # strategy, panel port specs, cable test procedure
  buildroot-external/                   # BR2_EXTERNAL: defconfig, board files, retroarch pkgs
  kernel/                               # panel-ek79007.c + our board DTS
  launcher/                             # launcher source (ported from Lyra)
  configs/                              # DTS drafts, retroarch cfg
  scripts/                              # build / patch-staging scripts
  firmware/                             # built images and binaries
  tools/                                # host-side tools
```

**Do not modify anything under `~/Lyra-sdk`** — that is the other project's working SDK.
It is a read-only source of ported artifacts.

## Reference links

- Board docs: https://docs.banana-pi.org/en/BPI-M2_Magic/BananaPi_BPI-M2_Magic
- sunxi wiki: https://linux-sunxi.org/Sinovoip_Banana_Pi_M2_Magic
- Mainline DTS: `arch/arm/boot/dts/allwinner/sun8i-r16-bananapi-m2m.dts`
- U-Boot defconfig: `Bananapi_m2m_defconfig`
