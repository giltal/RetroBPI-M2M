# Flashing and first boot

## Export the image to the Windows side

```bash
wsl bash -c "cp ~/bpi/output/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/"
```

`sdcard.img` is ~537 MB: a raw sunxi layout — SPL at 8 KB, U-Boot, then one ext4 rootfs with
`/boot/extlinux` inside it.

## Write it to the card

Use **balenaEtcher**, **Rufus** (DD mode) or **Win32DiskImager**. Do *not* try `dd` to a
`/dev/sdX` from WSL — WSL2 does not pass through removable block devices by default, and
guessing the wrong node on the host is how you lose a disk.

Format the card first with SD Card Formatter if it has been used for another sunxi image; the
BROM reads a raw offset, so a stale SPL can survive a partition-table rewrite.

## First boot — serial console

There is **no HDMI on this board**, so the serial console is the only window until the panel works.

- **CON3**: P1 GND, P2 UART0-RX, P3 UART0-TX
- **115200 8N1**
- Any USB-TTL adapter works at this baud (unlike the Lyra, which needed 1.5 Mbps-capable silicon)

> **If UART0 is silent, try UART2 before concluding the board is dead.** The vendor docs note that
> the SD-card pins and UART0 overlap on some configurations — Banana Pi published a separate eMMC
> image specifically to free UART0 for debug. This is a known trap, not a fault.

Expected sequence: SPL banner → U-Boot → extlinux → kernel → BusyBox init → login prompt on
`ttyS0`. Root has no password.

## Which DTB

Two are built and both land in `/boot`:

| DTB | Use |
|---|---|
| `sun8i-r16-bananapi-m2m.dtb` | **stock** — boot this first, no display nodes, proves the board |
| `sun8i-a33-bananapi-m2m-ek79007.dtb` | panel bring-up |

`extlinux.conf` uses `fdtdir /boot`, so U-Boot picks by the board's compatible string. To force
one, replace `fdtdir` with an explicit `fdt /boot/<name>.dtb`.

## Connecting to the board

Three channels. Serial always works; the other two need the board configured.

### Serial — always available
CON3, 115200 8N1. Root password is **`retrobpi`** (set in the defconfig — change it before this
goes anywhere real).

### ADB over the micro-USB
Plug the micro-USB into the PC. The board composes a functionfs gadget at boot
(`/etc/init.d/S50adbd`) and runs `adbd`. Host side, reuse the Lyra's platform-tools:

```bash
C:\LuckFox_Projects\LyraZeroW_SuperRetroPack\tools\platform-tools\adb.exe devices
```

Then `adb shell`, and `adb push <file> /usr/bin/...` — remember to `chmod +x` after a push, adb
drops the execute bit (same trap as on the Lyra).

If nothing enumerates, on the board:
```bash
/etc/init.d/S50adbd restart   # it prints where it failed
ls /sys/class/udc             # empty => OTG port is not in peripheral mode
```
The OTG port picks its role from the ID pin (PH8). A standard micro-B cable to a PC leaves ID
floating, which is peripheral mode. An OTG/host adapter cable grounds ID and you will get no
gadget.

### Wi-Fi + SSH
Nothing happens until a network is configured — `S49wifi` deliberately skips if
`/etc/wpa_supplicant.conf` has no `ssid=` line, so an unconfigured board boots at full speed.

```bash
wpa_passphrase "MySSID" "mypassphrase" >> /etc/wpa_supplicant.conf
/etc/init.d/S49wifi restart
ip addr show wlan0
```

Then `ssh root@<ip>` (dropbear). Firmware for the AP6212 is vendored in the image at
`/lib/firmware/brcm/brcmfmac43430-sdio.{bin,txt}` — Buildroot's `linux-firmware` ships the AP6212
nvram but not `brcmfmac43430-sdio.bin` for this chip revision, so both are carried in the overlay.

## First checks

```bash
dmesg | grep -i mmc          # settles whether an eMMC really is absent
cat /proc/cmdline
ls /dev/dri                  # expect card0/card1 — sun4i-drm and lima
i2cdetect -y 0               # panel MCU / touch, once the ribbon is connected
```

`i2cdetect` is the cheap cable test: it exercises the ribbon's I2C pair, the 3V3 ear and the
ground return with no DSI involved. See `cable_bringup_test.md`.
