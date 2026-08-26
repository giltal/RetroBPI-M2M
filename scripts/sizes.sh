D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
strings ~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so | grep -i "screensize\|Resolution;" | head -5
