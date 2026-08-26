#!/bin/sh
C=/usr/lib/libretro/paralleln64_libretro.so
echo "installed core size : $(wc -c < $C)"
echo "stock backup size   : $(wc -c < /tmp/n64_stock.so 2>/dev/null)"
echo "--- markers in installed core ---"
for m in 'SEC t=' 'clip=' 'peak=' 'glitch.log'; do
  echo "  '$m' : $(strings $C | grep -c "$m")"
done
echo "--- same markers in the stock backup (should all be 0) ---"
for m in 'SEC t=' 'clip='; do
  echo "  '$m' : $(strings /tmp/n64_stock.so 2>/dev/null | grep -c "$m")"
done
