#!/bin/sh
# Interleaved A/B test of 384 vs 528 MHz, with the ACTUAL clock sampled DURING
# each run.
#
# Two things this checks that the previous sweep did not:
#   1. Repeats, interleaved (A B A B A B) so any drift over the session hits
#      both arms equally. The earlier single pair gave 16.77 vs 16.76 s, which is
#      close enough to be one sample of noise rather than a real null result.
#   2. Whether the pinned clock HOLDS while the game runs. It was verified before
#      each run, never during -- and devfreq's cur_freq reports the OPP it chose,
#      not the hardware rate, so only debugfs answers this.
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE=/usr/lib/libretro/paralleln64_libretro.so
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
D=/sys/class/devfreq/1c40000.gpu
CLK=/sys/kernel/debug/clk/gpu/clk_rate
N1=4800
N2=5700

mount -t debugfs none /sys/kernel/debug 2>/dev/null
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

pin() {
	echo 144000000 > $D/min_freq 2>/dev/null
	echo $1 > $D/max_freq 2>/dev/null
	echo $1 > $D/min_freq 2>/dev/null
}

run() {   # $1 = frames -> prints "elapsed midrun_clock_mhz"
	_t0=$(cut -d' ' -f1 /proc/uptime)
	retroarch -L "$CORE" "$ROM" --max-frames=$1 --appendconfig /tmp/bench.cfg >/dev/null 2>&1 &
	_p=$!
	sleep 8
	_mid=$(cat $CLK 2>/dev/null)      # the clock WHILE the game is rendering
	wait $_p 2>/dev/null
	_t1=$(cut -d' ' -f1 /proc/uptime)
	awk -v a=$_t0 -v b=$_t1 -v m=$_mid 'BEGIN{printf "%.2f %d", b-a, m/1000000}'
}

printf "%-6s %-9s %8s %8s %8s %8s %10s\n" "round" "gpu" "t(N1)" "t(N2)" "delta" "fps" "clk_midrun"
for r in 1 2 3; do
	for F in 384000000 528000000; do
		pin $F
		set -- $(run $N1); A=$1; MA=$2
		sleep 1
		set -- $(run $N2); B=$1; MB=$2
		sleep 1
		awk -v r="$r" -v g="$((F/1000000))MHz" -v f=$((N2-N1)) -v a="$A" -v b="$B" -v m="$MB" \
		  'BEGIN{d=b-a; if(d<5){printf "%-6s %-9s %8.2f %8.2f   FAILED\n",r,g,a,b; exit}
		         printf "%-6s %-9s %8.2f %8.2f %8.2f %8.1f %9dMHz\n", r,g,a,b,d,f/d,m}'
	done
done

pin 144000000; echo 384000000 > $D/max_freq; echo 144000000 > $D/min_freq
cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "restored: max=$(cat $D/max_freq)  $(grep screensize "$OPT")"
