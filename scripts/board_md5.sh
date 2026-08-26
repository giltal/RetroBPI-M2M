#!/bin/sh
# md5 the things that matter, on the board
for f in /usr/bin/retrobpi_launcher \
         /usr/bin/retroarch \
         /root/.config/retroarch/retroarch.cfg \
         /etc/init.d/S05powercap \
         /etc/init.d/S12launcher \
         /etc/init.d/S35alsa \
         /boot/zImage \
         /boot/sun8i-a33-bananapi-m2m-ws5b.dtb ; do
  if [ -e "$f" ]; then echo "$(md5sum "$f" | cut -d' ' -f1)  $f"
  else echo "MISSING                            $f"; fi
done
echo "--- cores ---"
md5sum /usr/lib/libretro/*.so 2>/dev/null | sed 's|/usr/lib/libretro/||' | sort -k2
echo "--- N64 override present? ---"
ls "/root/.config/retroarch/config/ParaLLEl N64/" 2>/dev/null
echo "--- kernel version ---"
uname -r
