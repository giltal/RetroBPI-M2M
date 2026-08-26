#!/bin/bash
# Authoritative check that all board patches still apply to PRISTINE source.
#
# Cheaper than "make linux-dirclean && linux-rebuild": that would also produce a
# new zImage (different build id), which would then differ from the one running
# on the board and force another deploy+image cycle. Extracting a throwaway tree
# answers the only question that matters -- do the patches apply -- and touches
# nothing.
set -e
T=/tmp/pristine-linux
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/patches/linux
TAR=$(ls /home/giltal/bpi/dl/linux/linux-6.18.8.tar.* 2>/dev/null | head -1)
[ -n "$TAR" ] || TAR=$(find /home/giltal/bpi/dl -name 'linux-6.18.8.tar.*' | head -1)
echo "tarball: $TAR"

rm -rf "$T"; mkdir -p "$T"
tar xf "$TAR" -C "$T" --strip-components=1
echo "extracted pristine 6.18.8"
echo

cd "$T"
fail=0
for p in "$P"/0*.patch; do
	n=$(basename "$p")
	if patch -p1 --dry-run --force < "$p" >/tmp/pf.log 2>&1; then
		printf "  %-62s OK\n" "${n:0:62}"
		patch -p1 --force < "$p" >/dev/null 2>&1
	else
		printf "  %-62s FAILED\n" "${n:0:62}"
		sed 's/^/      /' /tmp/pf.log | head -6
		fail=1
	fi
done
cd /; rm -rf "$T"
echo
[ "$fail" = "0" ] && echo "ALL PATCHES APPLY TO PRISTINE SOURCE" || { echo "PATCH FAILURE"; exit 1; }
