#!/bin/sh
set -e
D=$(ls -d ~/bpi/output/build/libretro-fuse-*/)
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/patches/libretro-fuse
cd "$D"
diff -u --label a/src/libretro.c --label b/src/libretro.c \
     src/libretro.c.orig src/libretro.c > /tmp/f1.diff || true
{
  echo "fuse: Kempston joystick, and accept plain RETRO_DEVICE_JOYPAD"
  echo
  echo "The joystick did nothing in ZX Spectrum games despite fuse.cfg already"
  echo "requesting Kempston (input_libretro_device_p1 = 513). The config was"
  echo "never the problem."
  echo
  echo "RetroArch calls retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD)"
  echo "after core init. Plain JOYPAD (value 1) matches none of the Spectrum"
  echo "joystick cases in the switch, so it falls through to default:, which"
  echo "records input_devices[port] but never assigns joystick_1_output. The"
  echo "joystick is then silently dead whatever the user presses, and whatever"
  echo "the frontend config asked for."
  echo
  echo "Two changes:"
  echo "  1. port 0 defaults to Kempston rather than Cursor. Cursor maps the"
  echo "     stick to keyboard keys; Kempston is what Spectrum software expects."
  echo "  2. plain RETRO_DEVICE_JOYPAD is treated as Kempston, so joystick input"
  echo "     survives whatever the frontend sends."
  echo
  echo "Ported from the LyraZeroW project, which hit and solved this on the same"
  echo "fuse commit (69a44421). Its log also notes the override directory is"
  echo "case-sensitive: the core reports library_name \"fuse\", so the config"
  echo "must live at config/fuse/fuse.cfg, not config/Fuse/Fuse.cfg."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  cat /tmp/f1.diff
} > "$P/0002-fuse-kempston-joystick.patch"
echo "patch written: $(wc -l < "$P/0002-fuse-kempston-joystick.patch") lines"
ls -la "$P/"
