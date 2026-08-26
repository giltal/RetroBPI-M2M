#!/bin/sh
T=$HOME/bpi/output/target
echo "=== new files in the image tree ==="
for f in usr/sbin/net-hotplug usr/sbin/wifi-setup \
         etc/udev/rules.d/70-net-hotplug.rules \
         boot/extlinux/extlinux.conf boot/zImage ; do
  if [ -e "$T/$f" ]; then
    printf '  %-44s present\n' "$f"
  else
    printf '  %-44s MISSING\n' "$f"
  fi
done
echo
echo "=== kernel cmdline baked into the image ==="
grep -h 'append' "$T/boot/extlinux/extlinux.conf" 2>/dev/null | sed 's/^/  /'
echo
echo "=== kernel in image vs board ==="
echo "  images/zImage : $(md5sum $HOME/bpi/output/images/zImage | cut -d' ' -f1)"
echo "  target/zImage : $(md5sum $T/boot/zImage 2>/dev/null | cut -d' ' -f1)"
echo
echo "=== hot-plug script is executable in the image? ==="
ls -l "$T/usr/sbin/net-hotplug" "$T/usr/sbin/wifi-setup" 2>/dev/null | sed 's/^/  /'
