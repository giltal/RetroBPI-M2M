#!/bin/sh
echo "=== power supply sensors available ==="
for d in /sys/class/power_supply/*/; do
  echo "--- $d ---"
  for f in "$d"*; do
    case "$(basename $f)" in
      voltage_now|current_now|online|present|voltage_min_design|health|status)
        echo "  $(basename $f) = $(cat $f 2>/dev/null)";;
    esac
  done
done
echo
echo "=== hwmon (AXP internal ADCs) ==="
for h in /sys/class/hwmon/hwmon*/; do
  echo "--- $h $(cat $h/name 2>/dev/null) ---"
  ls $h | grep -E '^in[0-9]|^curr|^temp' | head -10
done
echo
echo "=== amp enable GPIO (PH9) and codec DAPM ==="
cat /sys/kernel/debug/gpio 2>/dev/null | grep -i -A2 'PH9\|pio' | head -10 || echo "  (no debugfs gpio)"
echo
echo "=== ASoC DAPM power states for the amp/HP path ==="
for w in /sys/kernel/debug/asoc/*/dapm/* ; do
  n=$(basename $w)
  case "$n" in *Speaker*|*HP*|*DAC*|*Amp*) echo "  $n: $(head -1 $w 2>/dev/null)";; esac
done 2>/dev/null | head -12
echo
echo "=== pmdown_time (delay before DAPM powers down) ==="
find /sys/devices -name pmdown_time 2>/dev/null | head -3 | while read f; do echo "  $f = $(cat $f)"; done
