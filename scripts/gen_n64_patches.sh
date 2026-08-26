#!/bin/sh
set -e
D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/package/retroarch/libretro-paralleln64
mkdir -p "$P"

A=mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c
B=libretro/libretro.c

cd "$D"
# patches must apply from the package root with -p1
diff -u --label "a/$A" --label "b/$A" "$A.orig" "$A" > /tmp/p1.diff || true
diff -u --label "a/$B" --label "b/$B" "$B.orig" "$B" > /tmp/p2.diff || true

{
  echo "N64 audio: headroom, native 48 kHz, better resampler quality"
  echo
  echo "Three measured fixes to the core's audio backend."
  echo
  echo "1. Clipping. 436 samples pinned at full scale in one session, peak 32768"
  echo "   (the clamp limit), audible as distortion. The clamp is in"
  echo "   convert_float_to_s16 after sinc resampling; sinc overshoots on"
  echo "   intersample peaks so near-0 dBFS material exceeds full scale even with"
  echo "   every gain stage at unity. Measured overshoot 1060 permille. Fixed by"
  echo "   attenuating before the resampler -- lowering the ALSA volume cannot"
  echo "   fix it, as the damage happens inside the core."
  echo
  echo "2. Double resampling. The core targeted a hardcoded 44100 while the codec"
  echo "   runs at 48000, so audio was converted twice (32000->44100->48000).  "
  echo "   Targeting 48000 gives a single conversion at exactly 1.5 for a 32 kHz"
  echo "   game. Verified by capturing the stream: >16 kHz energy at -116 dB."
  echo
  echo "3. Resampler quality raised from DONTCARE to HIGHER."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  cat /tmp/p1.diff
} > "$P/0002-n64-audio-headroom-and-native-48khz.patch"

{
  echo "N64: declare 48 kHz so the frontend does not resample"
  echo
  echo "Pairs with 0002. With the core producing 48000 natively and the codec"
  echo "running at 48000, declaring it here means RetroArch performs no rate"
  echo "conversion at all."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  cat /tmp/p2.diff
} > "$P/0003-n64-declare-48khz-sample-rate.patch"

echo "=== patches written ==="
for f in "$P"/*.patch; do echo "  $(basename $f)  $(wc -l < $f) lines"; done
