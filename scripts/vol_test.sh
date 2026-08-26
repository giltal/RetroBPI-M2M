#!/bin/sh
# Analog-only volume change. Digital stages stay at unity; the samples are
# already proven clean, so this isolates the analog output stage / speaker.
V=${1:-38}
CUR=$(amixer -c 0 cget name='Headphone Playback Volume' 2>/dev/null | grep -m1 '^  : values' | cut -d= -f2)
amixer -c 0 cset name='Headphone Playback Volume' $V >/dev/null 2>&1
NEW=$(amixer -c 0 cget name='Headphone Playback Volume' | grep -m1 '^  : values' | cut -d= -f2)
echo "headphone volume: $CUR -> $NEW  of 63   (scale is 1 dB per step)"
echo "change: $((NEW - CUR)) dB"
echo "digital stages (unchanged, at unity):"
for c in "AIF1 DA0 Playback Volume" "DAC Playback Volume"; do
  echo "  $c = $(amixer -c 0 cget name="$c" | grep -m1 '^  : values' | cut -d= -f2)"
done
