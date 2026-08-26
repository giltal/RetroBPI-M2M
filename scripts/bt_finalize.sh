#!/bin/bash
set -e
O=/home/giltal/bpi/output
FW=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img

echo "=== kernel that went into the image ==="
echo "images/zImage      : $(md5sum $O/images/zImage | cut -d' ' -f1)"
echo "target/boot/zImage : $(md5sum $O/target/boot/zImage | cut -d' ' -f1)"
echo "running on board   : 6f921583549cc98509ecb7c7abf383c4 (expected)"
[ "$(md5sum $O/target/boot/zImage | cut -d' ' -f1)" = "6f921583549cc98509ecb7c7abf383c4" ] \
  || { echo "FATAL: image kernel is not the patched one"; exit 1; }
echo "match: image carries the patched kernel"

echo
echo "=== DTB still carries local-bd-address ==="
DTB=$O/target/boot/sun8i-a33-bananapi-m2m-ws5b.dtb
if command -v fdtget >/dev/null 2>&1; then
	fdtget "$DTB" /soc/serial@1c28400/bluetooth local-bd-address 2>&1 || echo "(fdtget path miss)"
else
	# no fdtget -- the raw bytes are enough to prove the property survived
	if strings -a "$DTB" | grep -q 'local-bd-address'; then
		echo "local-bd-address property present in DTB"
	else
		echo "FATAL: property missing from DTB"; exit 1
	fi
fi

echo
echo "=== N64 core still clean (post-build guard already ran, confirming) ==="
C=$O/target/usr/lib/libretro/paralleln64_libretro.so
[ -f "$C" ] || { echo "FATAL: core missing"; exit 1; }
N=$(strings "$C" | grep -cE 'astick\.log|glitch\.log|ra_audio\.log|speed_permille' || true)
echo "instrumentation markers: $N (must be 0)"
[ "$N" = "0" ] || exit 1

echo
echo "=== copy to firmware/ ==="
cp "$O/images/sdcard.img" "$FW"
echo "img md5 : $(md5sum $O/images/sdcard.img | cut -d' ' -f1)"
echo "fw  md5 : $(md5sum $FW | cut -d' ' -f1)"
