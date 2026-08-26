D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
sed -n "1680,1740p" $D/libretro/libretro.c
