#!/bin/sh
# Does N64 speed at 640x480 scale with the Mali clock?
#
# This answers "is overclocking worth it" WITHOUT touching voltage, OPP tables or
# the DTS. The GPU has three OPPs (144/240/384 MHz). Pin each in turn and measure
# the same gameplay window. If throughput scales with clock, the GPU is the
# limiter and an overclock buys speed roughly in proportion. If it flattens, the
# bottleneck is elsewhere and 600 MHz would be risk for nothing.
#
# Pinning via min_freq==max_freq: only simple_ondemand is compiled in, so there
# is no "performance" governor to select. Pinning also removes governor ramp lag
# from the measurement.
#
# Two-point method (see n64_bench2.sh): time(N2)-time(N1) cancels startup AND the
# title screen, which is not GPU-bound and would dilute the result.
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE=/usr/lib/libretro/paralleln64_libretro.so
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
D=/sys/class/devfreq/1c40000.gpu
N1=${1:-4800}
N2=${2:-5700}

ps w | grep -q '[r]etroarch' && { echo "retroarch already running"; exit 2; }
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
# The launcher holds DRM master. If it survives the stop, EVERY RetroArch run
# dies instantly with "[KMS]: Error when switching mode" and the benchmark
# happily reports the resulting ~1 s runs as blistering speed. That happened:
# a whole sweep produced '90000 fps'. Verify the effect, not the return code.
if pidof retrobpi_launcher >/dev/null 2>&1; then
	echo "ABORT: launcher still running; it holds DRM master"; exit 3
fi
cp "$OPT" /tmp/opt.keep
ORIG_MIN=$(cat $D/min_freq); ORIG_MAX=$(cat $D/max_freq)

cat > /tmp/bench.cfg <<'X'
video_vsync = "false"
audio_sync = "false"
video_threaded = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
X

cat > "$OPT" <<'X'
parallel-n64-cpucore = "dynamic_recompiler"
parallel-n64-gfxplugin = "rice"
parallel-n64-gfxplugin-accuracy = "low"
parallel-n64-rspplugin = "hle"
parallel-n64-screensize = "640x480"
parallel-n64-framerate = "original"
parallel-n64-audio-buffer-size = "2048"
parallel-n64-send_allist_to_hle_rsp = "enabled"
parallel-n64-astick-sensitivity = "100"
parallel-n64-astick-deadzone = "5"
X

run() {
	_t0=$(cut -d' ' -f1 /proc/uptime)
	retroarch -L "$CORE" "$ROM" --max-frames=$1 --appendconfig /tmp/bench.cfg >/dev/null 2>&1
	_t1=$(cut -d' ' -f1 /proc/uptime)
	# A real run of thousands of frames cannot finish in ~1 s. That only
	# happens when RetroArch failed to open the video driver.
	_d=$(awk -v a=$_t0 -v b=$_t1 'BEGIN{printf "%.2f", b-a}')
	case $(awk -v d=$_d 'BEGIN{print (d<3)?"bad":"ok"}') in
		bad) echo "ABORT: run of $1 frames took ${_d}s -- RetroArch did not start" >&2; exit 4 ;;
	esac
	echo "$_d"
}

echo "640x480 rice, window = frames $N1..$N2 ($((N2-N1)) frames)"
printf "%-12s %8s %8s %8s %8s %7s\n" "gpu_mhz" "t(N1)" "t(N2)" "delta" "fps" "vs60"
for F in 144000000 240000000 384000000; do
	# order matters: lower min before max, or the write is rejected
	echo 144000000 > $D/min_freq 2>/dev/null
	echo $F > $D/max_freq 2>/dev/null
	echo $F > $D/min_freq 2>/dev/null
	ACT=$(cat $D/cur_freq)
	A=$(run $N1); sleep 1
	B=$(run $N2); sleep 1
	awk -v g=$((F/1000000)) -v act="$ACT" -v f=$((N2-N1)) -v a="$A" -v b="$B" \
	  'BEGIN{d=b-a; if(d<=0){printf "%-12s %8.2f %8.2f  BAD\n", g"MHz", a, b; exit}
	         printf "%-12s %8.2f %8.2f %8.2f %8.1f %6.0f%%\n", g"MHz", a, b, d, f/d, (f/d)/60*100}'
done

echo 144000000 > $D/min_freq 2>/dev/null
echo $ORIG_MAX > $D/max_freq 2>/dev/null
echo $ORIG_MIN > $D/min_freq 2>/dev/null
cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "restored: gpu min=$(cat $D/min_freq) max=$(cat $D/max_freq), $(grep screensize "$OPT")"
