#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
make O=~/bpi/output libretro-paralleln64-rebuild 2>&1 | tail -15
ls -la --time-style=+%H:%M ~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
strings ~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so | grep -c AL_DBG
