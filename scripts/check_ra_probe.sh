#!/bin/sh
T=$HOME/bpi/output/target/usr/bin
ls -la $T/retroarch $T/retroarch.bin 2>/dev/null
echo "--- wrapper contents ---"
cat $T/retroarch 2>/dev/null
echo "--- probe strings in the real binary ---"
for m in RETROBPI_AUDIO_PROBE headroom_permille ra_audio.log; do
  printf '  %-22s %s\n' "$m" "$(strings $T/retroarch.bin 2>/dev/null | grep -c "$m")"
done
