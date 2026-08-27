#!/bin/bash
# Static hunk arithmetic is not proof -- patch(1) is. Verify against pristine.
set -e
T=/tmp/pristine-oc
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/patches/linux
TAR=$(find /home/giltal/bpi/dl -name 'linux-6.18.8.tar.*' | head -1)
rm -rf "$T"; mkdir -p "$T"
tar xf "$TAR" -C "$T" --strip-components=1
cd "$T"
fail=0
for p in "$P"/0*.patch; do
	if patch -p1 --dry-run --force < "$p" >/tmp/pf.log 2>&1; then
		printf "  %-60s OK\n" "$(basename "$p" | cut -c1-60)"
		patch -p1 --force < "$p" >/dev/null 2>&1
	else
		printf "  %-60s FAILED\n" "$(basename "$p" | cut -c1-60)"
		sed 's/^/      /' /tmp/pf.log | head -5
		fail=1
	fi
done
cd /; rm -rf "$T"
[ "$fail" = "0" ] && echo "ALL 8 PATCHES APPLY TO PRISTINE SOURCE" || { echo "PATCH FAILURE"; exit 1; }
