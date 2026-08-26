#!/bin/sh
echo "uptime      : $(cut -d. -f1 /proc/uptime)s"
echo "kernel      : $(uname -r)  built $(uname -v | cut -c1-40)"
echo "zImage md5  : $(md5sum /boot/zImage | cut -d' ' -f1)"
echo "cmdline     : $(cat /proc/cmdline)"
echo
echo "=== fbcon rotation ==="
echo "  sysfs rotate     : $(cat /sys/class/graphics/fbcon/rotate 2>/dev/null || echo '(absent)')"
echo "  sysfs rotate_all : $(cat /sys/class/graphics/fbcon/rotate_all 2>/dev/null || echo '(absent)')"
echo
echo "=== kernel messages about fbcon / drm ==="
dmesg 2>/dev/null | grep -iE 'fbcon|fb0|drm|console' | head -8
echo
echo "=== system health after the new kernel ==="
echo "  launcher : $(ps w | grep retrobpi_launcher | grep -v grep | wc -l) proc"
echo "  governor : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "  N64 res  : $(grep -h '^parallel-n64-screensize' '/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt')"
echo "  audio    : $(grep -h '^audio_driver' /root/.config/retroarch/retroarch.cfg)"
echo "  fallback : $([ -f /boot/zImage.prev ] && echo 'zImage.prev present' || echo 'MISSING')"
