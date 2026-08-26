#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
echo "=== dirclean: wipes the build tree, forcing patches to re-apply ==="
make O=~/bpi/output libretro-paralleln64-dirclean 2>&1 | tail -3
echo "=== rebuild from source + patches ==="
make O=~/bpi/output libretro-paralleln64 2>&1 | grep -iE 'Applying|patch|error|Error' | head -20
echo "=== result ==="
F=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
ls -la --time-style=+%H:%M $F
echo "instrumentation leaked into shipping core: $(strings $F | grep -c 'glitch.log\|speed_permille\|audio_probe')  (must be 0)"
D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "--- fixes present in the freshly patched source ---"
A=$D/mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c
echo "  headroom gain : $(grep -c 'AUDIO_HEADROOM_GAIN);' $A)"
echo "  48k target    : $(grep -c 'AUDIO_TARGET_RATE / GameFreq' $A)"
echo "  quality HIGHER: $(grep -c 'RESAMPLER_QUALITY_HIGHER' $A)"
echo "  declared 48k  : $(grep -c 'sample_rate = 48000.0' $D/libretro/libretro.c)"
