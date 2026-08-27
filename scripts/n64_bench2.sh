#!/bin/sh
# N64 GPU-load benchmark, two-point method.
#
# For each config, run to frame N1 and to frame N2 and take the difference:
#
#     time(N2) - time(N1)  =  exactly (N2-N1) frames of emulation
#
# This cancels TWO contaminants at once:
#   * ROM load and plugin init, which is seconds and differs per resolution;
#   * the title screen, which barely touches the rasteriser. Benchmarking it is
#     a mistake this project already made three times. N1 is past the ~75 s mark
#     where the attract demo starts, so the measured window is real gameplay.
#
# It also removes the need for a save state, which three separate routes failed
# to produce (no nc for network commands; savestate_auto_save needs a clean exit
# and parallel-n64 SIGSEGVs on teardown every run; F2 is gated behind the hotkey
# modifier in retroarch.cfg).
#
# vsync and audio sync MUST be off or every config is pinned to 60 fps.
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE=/usr/lib/libretro/paralleln64_libretro.so
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
N1=${1:-4800}
N2=${2:-7800}
SHOTS=/tmp/n64shots

ps w | grep -q '[r]etroarch' && { echo "retroarch already running"; exit 2; }
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
mkdir -p "$SHOTS"; rm -f "$SHOTS"/*.png
cp "$OPT" /tmp/opt.keep

cat > /tmp/bench.cfg <<'X'
video_vsync = "false"
audio_sync = "false"
video_threaded = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
X

run() {   # $1=frames  $2=shot path or empty
	_t0=$(cut -d' ' -f1 /proc/uptime)
	if [ -n "$2" ]; then
		retroarch -L "$CORE" "$ROM" --max-frames=$1 --max-frames-ss \
			--max-frames-ss-path="$2" --appendconfig /tmp/bench.cfg >/dev/null 2>&1
	else
		retroarch -L "$CORE" "$ROM" --max-frames=$1 \
			--appendconfig /tmp/bench.cfg >/dev/null 2>&1
	fi
	_t1=$(cut -d' ' -f1 /proc/uptime)
	awk -v a=$_t0 -v b=$_t1 'BEGIN{printf "%.2f", b-a}'
}

CONFIGS='rice-320x240|rice|320x240|low
rice-400x300|rice|400x300|low
rice-480x360|rice|480x360|low
rice-512x384|rice|512x384|low
rice-640x480|rice|640x480|low
glide64-640x480|glide64|640x480|low'

echo "window = frames $N1..$N2 ($((N2-N1)) frames of attract-demo gameplay)"
printf "%-20s %8s %8s %8s %8s %7s\n" "config" "t(N1)" "t(N2)" "delta" "fps" "vs60"
echo "$CONFIGS" | while IFS='|' read NAME PLUG RES ACC; do
	[ -n "$NAME" ] || continue
	cat > "$OPT" <<X
parallel-n64-cpucore = "dynamic_recompiler"
parallel-n64-gfxplugin = "$PLUG"
parallel-n64-gfxplugin-accuracy = "$ACC"
parallel-n64-rspplugin = "hle"
parallel-n64-screensize = "$RES"
parallel-n64-framerate = "original"
parallel-n64-audio-buffer-size = "2048"
parallel-n64-send_allist_to_hle_rsp = "enabled"
parallel-n64-astick-sensitivity = "100"
parallel-n64-astick-deadzone = "5"
X
	A=$(run $N1 ""); sleep 1
	B=$(run $N2 "$SHOTS/$NAME.png"); sleep 1
	awk -v n="$NAME" -v f=$((N2-N1)) -v a="$A" -v b="$B" \
	   'BEGIN{d=b-a; if(d<=0){printf "%-20s %8.2f %8.2f  BAD (delta<=0)\n",n,a,b; exit}
	          printf "%-20s %8.2f %8.2f %8.2f %8.1f %6.0f%%\n", n, a, b, d, f/d, (f/d)/60*100}'
done

cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "=== restored: $(grep screensize "$OPT") ==="
echo "screenshots: $(ls "$SHOTS" 2>/dev/null | tr '\n' ' ')"
