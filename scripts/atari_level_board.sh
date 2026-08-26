#!/bin/sh
# Meter the Atari 800 core's actual output level at several gains.
CORE=/usr/lib/libretro/atari800_libretro.so
ROM="/opt/roms/atari800/ARKANOID.ATR"
CFG="/root/.config/retroarch/config/Atari800/Atari800.cfg"
W=25
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
[ -f "$ROM" ] || { echo "no ROM at $ROM"; exit 1; }
cp "$CFG" /tmp/atari.cfg.bak 2>/dev/null
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

run() {
  G="$1"
  sed -i "s/^audio_volume = .*/audio_volume = \"$G\"/" "$CFG" 2>/dev/null
  grep -q '^audio_volume' "$CFG" || echo "audio_volume = \"$G\"" >> "$CFG"
  rm -f /tmp/ra_audio.log
  RETROBPI_AUDIO_PROBE=1 HOME=/root /usr/bin/retroarch.bin \
      -L "$CORE" "$ROM" >/dev/null 2>>/tmp/ra_stderr.log &
  P=$!
  sleep $W
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  N=$(grep -c '^AUD' /tmp/ra_audio.log 2>/dev/null)
  if [ "${N:-0}" -eq 0 ]; then
    printf 'gain=%-8s NO DATA (probe produced nothing)\n' "$G"
    return
  fi
  PK=$(grep '^AUD' /tmp/ra_audio.log | sed -n 's/.*peak=\([0-9]*\).*/\1/p' | sort -n | tail -1)
  HR=$(grep '^AUD' /tmp/ra_audio.log | sed -n 's/.*headroom_permille=\([0-9]*\).*/\1/p' | sort -n | tail -1)
  CL=$(grep '^AUD' /tmp/ra_audio.log | sed -n 's/.*clip=\([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')
  printf 'gain=%-8s samples=%-4s peak=%-6s of_full_scale=%s%%  clipped=%s\n' \
     "$G" "$N" "$PK" "$((HR/10))" "$CL"
}

echo "=== Atari 800 output level (ARKANOID.ATR, ${W}s each) ==="
run 0.000000
run 6.000000
run 9.000000
run 12.000000

cp /tmp/atari.cfg.bak "$CFG" 2>/dev/null
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored: $(grep -h '^audio_volume' "$CFG")"
