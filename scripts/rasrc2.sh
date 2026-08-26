D=$(ls -d ~/bpi/output/build/retroarch-* | head -1)
sed -n "535,578p" $D/audio/audio_driver.c
