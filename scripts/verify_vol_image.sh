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
echo "=== launcher persists the MIXER value, not its stale copy ==="
if strings "$T/usr/bin/retrobpi_launcher" | grep -q "Headphone Playback Volume. 2>/dev/null"; then ok "launcher queries the mixer at save time"; else bad "launcher still saves g_volume"; fi
echo "=== volumed uses the launcher scale and its state file ==="
if strings "$T/usr/bin/volumed" | grep -q "/opt/roms/_system/state.txt"; then ok "volumed persists through state.txt"; else bad "volumed does not write state.txt"; fi
if strings "$T/usr/bin/volumed" | grep -q "Headphone Playback Volume"; then ok "volumed drives the same control"; else bad "volumed control mismatch"; fi
echo "=== fresh-flash default is not deafening ==="
if grep -q "g_volume = 40" /mnt/c/BananaPi_Projects/RetroBPI_M2M/launcher/launcher.c; then ok "launcher default 40% (was 80%)"; else bad "default not lowered"; fi
echo "=== BT trust fix (three lost pairings) ==="
if [ -x "$T/usr/sbin/bt-trust-paired" ]; then ok "bt-trust-paired present"; else bad "bt-trust-paired missing"; fi
if grep -q "var/lib/bluetooth" "$T/usr/sbin/bt-trust-paired"; then ok "enumerates bond dirs (paired-devices is empty for this pad)"; else bad "still uses paired-devices - would trust nothing"; fi
if grep -q "bt-trust-paired" "$T/etc/init.d/S41btagent"; then ok "S41btagent trusts at boot"; else bad "S41btagent does not trust"; fi
if strings "$T/usr/bin/volumed" | grep -q "bt-trust-paired"; then ok "volumed trusts on pad connect"; else bad "volumed missing trust call"; fi
echo "=== fsck for the FAT ROM partition ==="
if [ -x "$T/sbin/fsck.fat" ]; then ok "fsck.fat present (dosfstools installs nothing without a sub-option)"; else bad "fsck.fat missing - FAT damage would be undiagnosable on-board"; fi
echo "=== N64 quality toggle + Settings item ==="
if [ -x "$T/usr/sbin/n64-hires" ]; then ok "n64-hires helper present"; else bad "n64-hires missing"; fi
if strings "$T/usr/bin/retrobpi_launcher" | grep -q "N64 Quality"; then ok "Settings item compiled in"; else bad "Settings item missing"; fi
if grep -q "^GPU_MAX_DCIN=384000000" "$T/etc/init.d/S05powercap"; then ok "image defaults to stock 384 MHz (toggle is opt-in)"; else bad "image ships the overclock as default"; fi
if grep -q 'screensize = "320x240"' "$T/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"; then ok "image defaults to 320x240"; else bad "image ships 640x480 as default"; fi
echo "=== Recents/Favorites case-insensitive system match ==="
# NOTE: this one cannot be checked at the binary level. system_from_path() is a
# static function with no string literal of its own, so it leaves no symbol and
# no strings match -- the first version of this check grepped for a C COMMENT,
# which of course never survives compilation, and failed a perfectly good image.
# So: assert the source carries no active strstr matcher, and that the binary is
# newer than the source it came from. The behavioural confirmation is the
# on-hardware test (N64 launching from Recents), not this script.
L=/mnt/c/BananaPi_Projects/RetroBPI_M2M/launcher/launcher.c
n=$(grep -cE "^[[:space:]]*(if )?\(?strstr\(path, g_systems" "$L" || true)
if [ "$n" = "0" ]; then ok "no active strstr system matcher in the source"; else bad "$n active strstr matcher(s) remain"; fi
if [ "$T/usr/bin/retrobpi_launcher" -nt "$L" ]; then ok "launcher binary newer than launcher.c"; else bad "launcher binary is STALE relative to its source"; fi
echo "=== analog stick as d-pad on 2D cores ==="
if grep -q '^input_player1_analog_dpad_mode = "1"' "$T/root/.config/retroarch/retroarch.cfg"; then ok "global mode 1 (non-forced: N64/PSX keep real analog)"; else bad "analog_dpad_mode not set globally"; fi
if grep -q 'analog_dpad_mode = "3"' "$T/root/.config/retroarch/config/MAME 2003-Plus/MAME 2003-Plus.cfg"; then ok "MAME keeps forced mode 3"; else bad "MAME override lost"; fi
echo "=== clean shutdown from inside a game ==="
if grep -q "saving game" "$T/etc/init.d/S12launcher"; then ok "S12launcher SIGTERMs RetroArch and waits (saves flush)"; else bad "RetroArch would be SIGKILLed by init - SRAM at risk"; fi
if strings "$T/usr/bin/volumed" | grep -q "KEY_POWER seen at uptime"; then ok "volumed records that it saw the power key"; else bad "no power-key breadcrumb"; fi
if grep -q "shutdown_trace" "$T/etc/init.d/rcK" 2>/dev/null; then bad "diagnostic rcK trace leaked into the image"; else ok "rcK is pristine (no diagnostic trace shipped)"; fi
echo "=== everything else still intact ==="
[ "$(md5sum $T/boot/zImage | cut -d' ' -f1)" = "a6ab2523a5e8dd0052c40ef069e8ed6f" ] && ok "thermal kernel" || bad "kernel changed"
grep -q '^GPU_MAX_DCIN=384000000' "$T/etc/init.d/S05powercap" && ok "GPU at stock" || bad "GPU cap"
grep -q setsid "$T/usr/sbin/net-hotplug" && ok "net-hotplug fix" || bad "net-hotplug"
grep -q 'pidof "\$DAEMON"' "$T/etc/init.d/S12launcher" && ok "launcher stop fix" || bad "launcher stop"
n=0; for so in "$T"/usr/lib/libretro/*.so; do strings "$so" 2>/dev/null | grep -qE 'astick\.log|speed_permille' && n=1; done
[ "$n" = "0" ] && ok "no instrumented cores" || bad "instrumented core"
exit $fail
