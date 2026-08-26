#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'echo "uptime: $(cut -d" " -f1 /proc/uptime) s"; uptime; echo "governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"; echo "audio_driver: $(grep \"^audio_driver\" /root/.config/retroarch/retroarch.cfg)"; echo "latency: $(grep \"^audio_latency\" /root/.config/retroarch/retroarch.cfg)"' 2>&1 | grep -vi warning
