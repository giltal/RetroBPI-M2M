#!/bin/bash
T=/home/giltal/bpi/output/target
fail=0
ok(){ echo "  OK   $1"; }; bad(){ echo "  FAIL $1"; fail=1; }
echo "=== volumed in the image, and is it the POWER-handling build? ==="
[ -x "$T/usr/bin/volumed" ] && ok "volumed present ($(stat -c %s "$T/usr/bin/volumed") bytes)" || bad "volumed missing"
strings "$T/usr/bin/volumed" | grep -q 'axp20x-pek' && ok "watches the power key" || bad "no power-key support -- stale binary"
strings "$T/usr/bin/volumed" | grep -q 'poweroff' && ok "issues poweroff" || bad "no poweroff"
strings "$T/usr/bin/volumed" | grep -q 'Headphone' && ok "drives the ALSA Headphone control" || bad "no mixer control"
echo "=== init script ==="
[ -x "$T/etc/init.d/S45volumed" ] && ok "S45volumed" || bad "S45volumed missing"
echo "=== RetroArch must NOT also bind volume (would double-apply) ==="
grep -qE '^[[:space:]]*input_volume' "$T/root/.config/retroarch/retroarch.cfg" \
  && bad "retroarch.cfg still binds volume" || ok "no active volume bindings"
echo "=== everything else still intact ==="
[ "$(md5sum $T/boot/zImage | cut -d' ' -f1)" = "a6ab2523a5e8dd0052c40ef069e8ed6f" ] && ok "thermal kernel" || bad "kernel changed"
grep -q '^GPU_MAX_DCIN=384000000' "$T/etc/init.d/S05powercap" && ok "GPU at stock" || bad "GPU cap"
grep -q setsid "$T/usr/sbin/net-hotplug" && ok "net-hotplug fix" || bad "net-hotplug"
grep -q 'pidof "\$DAEMON"' "$T/etc/init.d/S12launcher" && ok "launcher stop fix" || bad "launcher stop"
n=0; for so in "$T"/usr/lib/libretro/*.so; do strings "$so" 2>/dev/null | grep -qE 'astick\.log|speed_permille' && n=1; done
[ "$n" = "0" ] && ok "no instrumented cores" || bad "instrumented core"
exit $fail
