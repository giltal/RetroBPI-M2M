#!/bin/bash
echo "=== u-boot build dirs ==="
ls -d /home/giltal/bpi/output/build/uboot* 2>/dev/null
U=$(ls -d /home/giltal/bpi/output/build/uboot-* 2>/dev/null | head -1)
[ -n "$U" ] || { echo "  none found"; exit 1; }
echo "using: $U"
echo
echo "=== was the fastboot fragment applied? ==="
for k in CONFIG_BOOTDELAY CONFIG_USB CONFIG_CMD_USB CONFIG_USB_STORAGE CONFIG_CMD_NET; do
  printf "  %-22s " "$k"
  grep -E "^${k}=|^# ${k} is not set" "$U/.config" 2>/dev/null | head -1 || echo "(absent)"
done
echo
echo "=== SPL/U-Boot binary sizes (smaller = less to load) ==="
ls -la "$U/u-boot.bin" "$U/spl/sunxi-spl.bin" 2>/dev/null | awk '{print "  "$5" "$9}'
echo
echo "=== kernel + dtb the bootloader must read off SD ==="
ls -la /home/giltal/bpi/output/images/zImage /home/giltal/bpi/output/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | awk '{printf "  %8d  %s\n",$5,$9}'
