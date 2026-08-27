#!/bin/sh
# Sustained-load thermal profile. First time this board can measure it at all.
#
# Runs the SHIPPING N64 configuration (320x240, rice) -- the realistic worst case
# for a play session, since N64 is the only system that pushes this SoC hard --
# and samples the cpu-thermal zone plus the cpufreq cooling state, so we can see
# both temperature AND whether the kernel started throttling.
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE=/usr/lib/libretro/paralleln64_libretro.so
Z=/sys/class/thermal/thermal_zone0
C=/sys/class/thermal/cooling_device0
SECS=${1:-180}

ps w | grep -q '[r]etroarch' && { echo "retroarch running"; exit 2; }
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
pidof retrobpi_launcher >/dev/null 2>&1 && { echo "ABORT: launcher still up"; exit 3; }

echo "idle temp   : $(( $(cat $Z/temp) / 1000 )) C"
echo "trip passive: $(( $(cat $Z/trip_point_0_temp) / 1000 )) C"
echo "cooling max : $(cat $C/max_state)  (cur=$(cat $C/cur_state))"
echo

retroarch -L "$CORE" "$ROM" --max-frames=$((SECS * 60)) >/dev/null 2>&1 &
P=$!
sleep 10

MAX=0; THROT=0; i=0
printf "%6s %7s %7s %9s\n" "t(s)" "temp" "cpu_mhz" "throttle"
while [ $i -lt $SECS ]; do
	kill -0 $P 2>/dev/null || break
	T=$(cat $Z/temp 2>/dev/null); T=$((T / 1000))
	S=$(cat $C/cur_state 2>/dev/null)
	F=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) / 1000 ))
	[ "$T" -gt "$MAX" ] && MAX=$T
	[ "$S" -gt 0 ] && THROT=1
	[ $((i % 20)) -eq 0 ] && printf "%6s %6s C %7s %9s\n" "$i" "$T" "$F" "$S"
	sleep 5; i=$((i + 5))
done

kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
echo
echo "=== summary ==="
echo "  peak temperature : $MAX C"
echo "  first passive trip: $(( $(cat $Z/trip_point_0_temp) / 1000 )) C"
echo "  throttled        : $([ $THROT -eq 1 ] && echo YES || echo no)"
echo "  headroom to trip : $(( $(cat $Z/trip_point_0_temp) / 1000 - MAX )) C"
echo "  cooling state now: $(cat $C/cur_state)/$(cat $C/max_state)"
/etc/init.d/S12launcher start >/dev/null 2>&1
