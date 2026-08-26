#!/bin/sh
# Native (unity-gain) peak of the Atari 800 core across several titles.
# Long windows: an ATR has to boot before it makes any noise, and a 25 s window
# measured nothing but the loading silence.
CORE=/usr/lib/libretro/atari800_libretro.so
CFG="/root/.config/retroarch/config/Atari800/Atari800.cfg"
W=70
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
cp "$CFG" /tmp/atari.cfg.bak 2>/dev/null
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

# unity gain, so the measured peak is the core's own level
sed -i 's/^audio_volume = .*/audio_volume = "0.000000"/' "$CFG" 2>/dev/null

run() {
  ROM="$1"
  [ -f "$ROM" ] || { printf '%-34s ROM MISSING\n' "$(basename "$ROM")"; return; }
  rm -f /tmp/ra_audio.log
  RETROBPI_AUDIO_PROBE=1 HOME=/root /usr/bin/retroarch.bin -L "$CORE" "$ROM" \
      >/dev/null 2>/dev/null &
  P=$!; sleep $W
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  PK=$(grep '^AUD' /tmp/ra_audio.log 2>/dev/null | sed -n 's/.*peak=\([0-9]*\).*/\1/p' | sort -n | tail -1)
  : ${PK:=0}
  # how many dB of gain would put this title at 90% of full scale
  HDR=$(awk -v p="$PK" 'BEGIN{ if(p<1) print "n/a"; else printf "%.1f", 20*log(29490/p)/log(10) }')
  printf '%-34s native_peak=%-6s (%2s%% FS)  room_to_90%%=%s dB\n' \
     "$(basename "$ROM")" "$PK" "$((PK * 100 / 32767))" "$HDR"
}

echo "=== Atari 800 native level at UNITY gain, ${W}s per title ==="
run "/opt/roms/atari800/ARKANOID.ATR"
run "/opt/roms/atari800/Asteroids.atr"
run "/opt/roms/atari800/AIRWOLF.ATR"

cp /tmp/atari.cfg.bak "$CFG" 2>/dev/null
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored: $(grep -h '^audio_volume' "$CFG")"
