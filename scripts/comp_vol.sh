#!/bin/sh
# Compensate the -1.94 dB of digital headroom with analog gain.
# Headphone scale is DECLARE_TLV_DB_SCALE(-6300, 100, 1): 1 dB per step, 0-63.
CUR=$(amixer -c 0 cget name='Headphone Playback Volume' 2>/dev/null | grep -m1 '^  : values' | cut -d= -f2)
echo "headphone before : $CUR / 63"
NEW=$((CUR + 2))
[ "$NEW" -gt 63 ] && NEW=63
amixer -c 0 cset name='Headphone Playback Volume' $NEW >/dev/null 2>&1
echo "headphone after  : $(amixer -c 0 cget name='Headphone Playback Volume' | grep -m1 '^  : values' | cut -d= -f2) / 63  (+2 dB, offsets the -1.94 dB)"
echo "digital stages unchanged at unity:"
for c in "AIF1 DA0 Playback Volume" "DAC Playback Volume"; do
  echo "  $c = $(amixer -c 0 cget name="$c" | grep -m1 '^  : values' | cut -d= -f2)"
done
rm -f /tmp/glitch.log
echo "glitch.log cleared - ready for a fresh race"
