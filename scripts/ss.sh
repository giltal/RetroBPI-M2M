D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== how screensize is consumed ==="
grep -n -B2 -A12 "parallel-n64-screensize" $D/libretro/libretro.c | head -40
