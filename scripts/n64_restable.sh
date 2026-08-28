#!/bin/sh
# N64 resolution vs speed, at the stock 384 MHz GPU.
#
# METRIC: total wall time to a fixed frame count, minus a separately measured
# startup (--max-frames=1). NOT the two-point delta used earlier: subtracting two
# ~100 s runs to extract a ~17 s window put all the noise from both totals onto
# the small result, and produced a 48.9-60.6 fps spread at a FIXED clock. The
# totals themselves are steady to a few hundredths of a second.
#
# rice exposes no quality knobs -- retro_filtering and retro_dithering are never
# read outside libretro.c, gfx_plugin_accuracy is glide64-only, vcache-vbo is
# read nowhere. Resolution is the only lever, and screensize goes through
# sscanf("%dx%d") so ANY WxH works, not just the menu list.
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE=/usr/lib/libretro/paralleln64_libretro.so
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
N=${1:-5700}

ps w | grep -q '[r]etroarch' && { echo "retroarch running"; exit 2; }
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
pidof retrobpi_launcher >/dev/null 2>&1 && { echo "ABORT: launcher holds DRM"; exit 3; }
cp "$OPT" /tmp/opt.keep

cat > /tmp/bench.cfg <<'X'
video_vsync = "false"
audio_sync = "false"
video_threaded = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
X

run() {
	_t0=$(cut -d' ' -f1 /proc/uptime)
	retroarch -L "$CORE" "$ROM" --max-frames=$1 --appendconfig /tmp/bench.cfg >/dev/null 2>&1
	_t1=$(cut -d' ' -f1 /proc/uptime)
	awk -v a=$_t0 -v b=$_t1 'BEGIN{printf "%.2f", b-a}'
}

printf "%-11s %8s %9s %9s %8s %7s  %s\n" "res" "start" "total" "emulate" "fps" "vs60" "pixels/frame"
for RES in 320x240 400x300 480x360 512x384 576x432 640x480; do
	sed -i "s/^parallel-n64-screensize = .*/parallel-n64-screensize = \"$RES\"/" "$OPT"
	S=$(run 1); sleep 1
	T=$(run $N); sleep 1
	W=${RES%x*}; H=${RES#*x}
	awk -v r="$RES" -v n="$N" -v s="$S" -v t="$T" -v w="$W" -v h="$H" \
	  'BEGIN{e=t-s; if(e<10){printf "%-11s   FAILED (%.2fs)\n", r, e; exit}
	         printf "%-11s %8.2f %9.2f %9.2f %8.1f %6.0f%% %10d\n", r, s, t, e, n/e, (n/e)/60*100, w*h}'
done

cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "restored: $(grep screensize "$OPT")"
