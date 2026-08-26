D=$(ls -d ~/bpi/output/build/libretro-atari800-* 2>/dev/null | head -1)
echo "core src: $D"
echo "=== virtual keyboard toggle binding ==="
grep -rn "RETRO_DEVICE_ID_JOYPAD_L3\|L3\|vkbd\|VKBD\|virtual.*key" $D/libretro/libretro.c 2>/dev/null | head -20
