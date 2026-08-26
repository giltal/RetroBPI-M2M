#!/bin/sh
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
sed -i 's|^parallel-n64-screensize = .*|parallel-n64-screensize = "320x240"|' "$OPT"
grep -q '^parallel-n64-screensize' "$OPT" || echo 'parallel-n64-screensize = "320x240"' >> "$OPT"
rm -f /tmp/glitch.log
echo "applied:"
grep -hE 'screensize|gfxplugin |framerate' "$OPT" | sed 's/^/  /'
