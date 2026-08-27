#!/bin/sh
# Validate each Mali overclock OPP in ascending order, stopping at the first
# rate that misbehaves.
#
# Ascending and fail-fast on purpose: this is a clock-only overclock (no
# opp-microvolt, no separate GPU rail), so an unstable rate cannot be tuned out
# -- it can only be avoided. A GPU hang on a board with no HDMI is expensive to
# diagnose, so we stop rather than push on.
#
# Each rate is checked for THREE things, not just speed:
#   1. the clock actually landed on the requested rate (devfreq will happily
#      report an OPP the hardware never reached);
#   2. the run completed (a failed launch must not be scored as fast -- an
#      earlier sweep reported "90000 fps" from RetroArch failing to start);
#   3. dmesg gained no lima errors (timeouts / resets are how a marginal GPU
#      clock actually manifests, and they do not stop the benchmark).
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE=/usr/lib/libretro/paralleln64_libretro.so
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
D=/sys/class/devfreq/1c40000.gpu
N1=${1:-4800}
N2=${2:-5700}

ps w | grep -q '[r]etroarch' && { echo "retroarch already running"; exit 2; }
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
pidof retrobpi_launcher >/dev/null 2>&1 && { echo "ABORT: launcher holds DRM master"; exit 3; }

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

restore() {
	echo 144000000 > $D/min_freq 2>/dev/null
	echo $ORIG_MAX > $D/max_freq 2>/dev/null
	echo $ORIG_MIN > $D/min_freq 2>/dev/null
	cp /tmp/opt.keep "$OPT"
	/etc/init.d/S12launcher start >/dev/null 2>&1
	echo "restored: gpu max=$(cat $D/max_freq), $(grep screensize "$OPT")"
}

run() {
	_t0=$(cut -d' ' -f1 /proc/uptime)
	retroarch -L "$CORE" "$ROM" --max-frames=$1 --appendconfig /tmp/bench.cfg >/dev/null 2>&1
	_t1=$(cut -d' ' -f1 /proc/uptime)
	awk -v a=$_t0 -v b=$_t1 'BEGIN{printf "%.2f", b-a}'
}

echo "available OPPs: $(cat $D/available_frequencies)"
printf "%-10s %10s %8s %8s %7s  %s\n" "request" "actual" "delta" "fps" "vs60" "lima_errors"
# 600 MHz is excluded: it produced ~1970 lima faults (pp task error, gp bus
# stop timeout) and there is no voltage headroom to stabilise it. 432 is
# excluded as redundant between 384 and 480.
for F in ${RATES:-384000000 480000000 528000000}; do
	echo 144000000 > $D/min_freq 2>/dev/null
	if ! echo $F > $D/max_freq 2>/dev/null; then
		printf "%-10s  OPP not available -- stopping\n" "$((F/1000000))MHz"; break
	fi
	echo $F > $D/min_freq 2>/dev/null
	ACT=$(cat $D/cur_freq)
	if [ "$ACT" != "$F" ]; then
		printf "%-10s %10s  clock did not land on the requested rate -- stopping\n" \
			"$((F/1000000))MHz" "$((ACT/1000000))MHz"
		break
	fi
	E0=$(dmesg | grep -ci 'lima.*\(timeout\|reset\|error\|fault\)' 2>/dev/null || echo 0)
	A=$(run $N1); sleep 1
	B=$(run $N2); sleep 2
	E1=$(dmesg | grep -ci 'lima.*\(timeout\|reset\|error\|fault\)' 2>/dev/null || echo 0)
	ERR=$((E1 - E0))
	OUT=$(awk -v g="$((F/1000000))MHz" -v act="$((ACT/1000000))MHz" -v f=$((N2-N1)) \
	          -v a="$A" -v b="$B" -v e="$ERR" \
	  'BEGIN{d=b-a;
	         if(d<5){printf "%-10s %10s   FAILED (window took %.2fs -- run did not complete)", g, act, d; exit}
	         printf "%-10s %10s %8.2f %8.1f %6.0f%%  %d", g, act, d, f/d, (f/d)/60*100, e}')
	echo "$OUT"
	case "$OUT" in *FAILED*) break;; esac
	[ "$ERR" -gt 0 ] && { echo "  lima errors at $((F/1000000))MHz -- stopping escalation"; break; }
done

restore
