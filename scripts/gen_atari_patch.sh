#!/bin/sh
set -e
D=$(ls -d ~/bpi/output/build/libretro-atari800-*/)
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/package/retroarch/libretro-atari800
cd "$D"
diff -u --label a/libretro/platform.c --label b/libretro/platform.c \
     libretro/platform.c.orig libretro/platform.c > /tmp/a1.diff || true
diff -u --label a/libretro/libretro-core.c --label b/libretro/libretro-core.c \
     libretro/libretro-core.c.orig libretro/libretro-core.c > /tmp/a2.diff || true
{
  echo "atari800: accept R as well as L3 for the virtual keyboard"
  echo
  echo "L3 alone is unusable on the DualShock 3 this device ships with."
  echo "Captured with evtest on the running board: clicking the left analog"
  echo "stick emits BTN_TL2 (312) and the right stick BTN_TR2 (313) -- the"
  echo "L2/R2 trigger codes. BTN_THUMBL (317) and BTN_THUMBR (318) appear in"
  echo "the device's advertised KEY bitmask but are never actually emitted,"
  echo "so the core could never observe its own toggle. Worse, platform.c"
  echo "maps L2 to AKEY_ESCAPE, so pressing the stick sent Escape instead."
  echo
  echo "R is free in this core: the input descriptors bind L (Option) but not"
  echo "R, and platform.c notes R was deliberately left unbound once AKEY_UI"
  echo "stopped doing anything. BTN_TR does arrive from this pad."
  echo
  echo "L3 is retained so the stock binding still works on hardware that"
  echo "reports thumb-stick clicks correctly."
  echo
  echo "Reference: the fuse core binds its keyboard overlay to SELECT and works"
  echo "on the same controller, which is what identified this as button-specific"
  echo "rather than a broken overlay."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  cat /tmp/a1.diff /tmp/a2.diff
} > "$P/0001-atari800-vkbd-on-R-as-well-as-L3.patch"
echo "patch written: $(wc -l < "$P/0001-atari800-vkbd-on-R-as-well-as-L3.patch") lines"
