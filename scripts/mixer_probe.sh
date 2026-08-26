#!/bin/sh
echo "=== digital gain stages (clipping happens here if too hot) ==="
for c in "AIF1 DA0 Playback Volume" "DAC Playback Volume" "Headphone Playback Volume"; do
  v=$(amixer -c 0 cget name="$c" 2>/dev/null | grep -m1 '^  : values' | cut -d= -f2)
  r=$(amixer -c 0 cget name="$c" 2>/dev/null | grep -m1 'range' | sed 's/.*range //;s/,.*//')
  echo "  $c = $v   (range $r)"
done
echo
echo "=== full amixer contents for the playback path ==="
amixer -c 0 contents 2>/dev/null | grep -A2 -iE 'DA0|DAC Playback|Headphone|Speaker' | grep -E 'numid|: values' | head -20
echo
echo "=== RetroArch volume setting ==="
grep -E '^audio_volume|^audio_mixer' /root/.config/retroarch/retroarch.cfg 2>/dev/null || echo "  (default 0.0 dB)"
