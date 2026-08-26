#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-atari800-*/ | head -1)
echo "=== makefiles present ==="
ls $SRC/Makefile* 2>/dev/null
echo
echo "=== SOUND / HAVE_SOUND defines anywhere in the build system ==="
grep -rn 'SOUND' $SRC/Makefile* 2>/dev/null | head -10
echo
echo "=== how the libretro layer feeds audio ==="
grep -rn 'audio_batch_cb\|retro_audio_batch_cb\|Sound_Callback\|sound_update' $SRC/libretro/libretro-core.c 2>/dev/null | head -10
echo
echo "=== is sound initialised? ==="
grep -rn 'Sound_Initialise\|Sound_Setup\|snd_enabled\|sound_enabled' $SRC/libretro/*.c $SRC/src/sound.c 2>/dev/null | head -10
