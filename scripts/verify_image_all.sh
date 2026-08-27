#!/bin/bash
T=/home/giltal/bpi/output/target
I=/home/giltal/bpi/output/images
fail=0
ok(){ echo "  OK   $1"; }
bad(){ echo "  FAIL $1"; fail=1; }

echo "=== thermal driver in the image kernel ==="
[ "$(md5sum $I/zImage | cut -d' ' -f1)" = "a6ab2523a5e8dd0052c40ef069e8ed6f" ] \
  && ok "zImage is the thermal build (a6ab2523), same as the board" \
  || bad "zImage md5 $(md5sum $I/zImage | cut -d' ' -f1) != board kernel"

echo "=== GPU OPPs in the booted DTB ==="
for f in 432000000 480000000 528000000 600000000; do
  fdtget "$I/sun8i-a33-bananapi-m2m-ws5b.dtb" /opp-table-gpu/opp-$f opp-hz >/dev/null 2>&1 \
    && ok "opp-$f present" || bad "opp-$f missing"
done

echo "=== GPU cap pinned at stock ==="
grep -q '^GPU_MAX_DCIN=384000000' "$T/etc/init.d/S05powercap" \
  && ok "S05powercap caps GPU at 384 MHz (measured: overclock buys ~1%)" \
  || bad "GPU cap is not 384 MHz"

echo "=== launcher stop() hardened ==="
grep -q 'pidof "\$DAEMON"' "$T/etc/init.d/S12launcher" \
  && ok "stop() verifies the process actually exited" \
  || bad "stop() still trusts start-stop-daemon"

echo "=== boot fixes ==="
grep -q setsid "$T/usr/sbin/net-hotplug" && ok "net-hotplug detached" || bad "net-hotplug"
[ -f "$T/etc/init.d/S51seedrefresh" ] && ok "S51seedrefresh" || bad "S51seedrefresh"
[ -x "$T/usr/bin/seed-credit" ] && ok "seed-credit" || bad "seed-credit"

echo "=== BT address still in the DTB ==="
fdtget "$I/sun8i-a33-bananapi-m2m-ws5b.dtb" /soc/serial@1c28400/bluetooth local-bd-address >/dev/null 2>&1 \
  && ok "local-bd-address present" || bad "local-bd-address missing"

echo "=== N64 ships at 320x240, not a benchmark leftover ==="
grep -q 'screensize = "320x240"' "$T/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt" \
  && ok "N64 at 320x240" || bad "N64 screensize is not the shipping value"

echo "=== no diagnostic instrumentation in any core ==="
n=0
for so in "$T"/usr/lib/libretro/*.so; do
  strings "$so" 2>/dev/null | grep -qE 'astick\.log|glitch\.log|ra_audio\.log|speed_permille' && { echo "  FAIL instrumented: $(basename $so)"; n=1; }
done
[ "$n" = "0" ] && ok "all cores clean" || fail=1

echo "=== rejected experiments absent ==="
for b in etc/init.d/S00ioperf etc/init.d/S48wifimod etc/modprobe.d/brcmfmac-defer.conf; do
  [ -e "$T/$b" ] && bad "$b leaked in"
done
[ "$fail" = "0" ] && ok "none present"
exit $fail
