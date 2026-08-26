#!/bin/bash
O=~/bpi/output
export MTOOLS_SKIP_CHECK=1
MDIR=$O/host/bin/mdir
[ -x "$MDIR" ] || MDIR=$(command -v mdir)
echo "using: $MDIR"
echo "=== folders on the ROM partition ==="
"$MDIR" -i $O/images/roms.vfat :: 2>&1 | head -35
