#!/bin/sh
# Does the probe see real audio at all? Test against a core known to be loud.
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

t() {
  NAME="$1"; CORE="$2"; ROM="$3"; W="$4"
  [ -f "$ROM" ] || { echo "$NAME: ROM missing"; return; }
  rm -f /tmp/ra_audio.log
  RETROBPI_AUDIO_PROBE=1 HOME=/root /usr/bin/retroarch.bin -L "$CORE" "$ROM" \
      >/dev/null 2>>/tmp/ra_stderr.log &
  P=$!; sleep $W
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  N=$(grep -c '^AUD' /tmp/ra_audio.log 2>/dev/null)
  PK=$(grep '^AUD' /tmp/ra_audio.log 2>/dev/null | sed -n 's/.*peak=\([0-9]*\).*/\1/p' | sort -n | tail -1)
  printf '%-14s probe_lines=%-4s max_peak=%-6s %s\n' "$NAME" "${N:-0}" "${PK:-0}" \
     "$([ "${PK:-0}" -gt 100 ] && echo 'PROBE SEES AUDIO' || echo 'silence or probe blind')"
}

echo "=== probe sanity check ==="
t NES    /usr/lib/libretro/fceumm_libretro.so      "/opt/roms/nes/1942 (Japan, USA).nes" 20
t SNES   /usr/lib/libretro/snes9x2005_libretro.so  "/opt/roms/snes/ActRaiser (USA).sfc"  20
echo
echo "=== atari800: longer run, and is it even booting? ==="
t Atari800_60s /usr/lib/libretro/atari800_libretro.so "/opt/roms/atari800/ARKANOID.ATR" 60
echo
echo "=== does atari800 need OS ROMs? ==="
ls -la /opt/roms/_system/bios/ 2>/dev/null | head -10
echo "--- retroarch stderr, atari-related ---"
grep -iE 'atari|rom|bios|error' /tmp/ra_stderr.log 2>/dev/null | tail -12
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### done"
