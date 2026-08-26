D=$(ls -d ~/bpi/output/build/retroarch-* 2>/dev/null | head -1)
echo "retroarch src: $D"
echo "=== where audio_volume / gain is applied ==="
grep -rn "volume_gain\|audio_driver_flush" $D/audio/audio_driver.c 2>/dev/null | head -12
echo "=== the s16 conversion just before the driver write ==="
grep -n "convert_float_to_s16\|current_audio->write" $D/audio/audio_driver.c 2>/dev/null | head -10
