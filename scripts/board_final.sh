#!/bin/sh
echo "core instrumented? markers=$(strings /usr/lib/libretro/paralleln64_libretro.so | grep -c GLITCH)"
echo "gfx/rsp: $(grep -h 'gfxplugin \|rspplugin ' "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt" | tr '\n' ' ')"
echo "audio  : $(grep -h '^audio_driver\|^audio_latency' /root/.config/retroarch/retroarch.cfg | tr '\n' ' ')"
echo "governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "launcher: $(ps w | grep retrobpi_launcher | grep -v grep | wc -l)  retroarch: $(ps w | grep retroarch.bin | grep -v grep | wc -l)  watchers: $(ps w | grep aw.sh | grep -v grep | wc -l)"
