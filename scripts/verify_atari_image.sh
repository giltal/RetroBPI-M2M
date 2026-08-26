#!/bin/sh
T=$HOME/bpi/output/target/usr/lib/libretro/atari800_libretro.so
echo "target core md5 : $(md5sum $T | cut -d' ' -f1)"
echo "target core has R-patch strings: $(strings $T | grep -c 'Virtual Keyboard (alt)')"
echo "opt in image    : $(grep -h '^atari800_vkbd_enabled' "$HOME/bpi/output/target/root/.config/retroarch/config/Atari800/Atari800.opt" 2>/dev/null)"
echo "cfg in image    : $(grep -h '^audio_volume' "$HOME/bpi/output/target/root/.config/retroarch/config/Atari800/Atari800.cfg" 2>/dev/null)"
echo "image built     : $(ls -la --time-style=+%H:%M $HOME/bpi/output/images/sdcard.img | awk '{print $6,$7}')"
