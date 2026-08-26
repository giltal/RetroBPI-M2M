#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'echo "governor : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"; echo "freq     : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"; echo "override : $(grep -h "^audio_latency" "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg" 2>/dev/null || echo MISSING)"; echo "gfxplugin: $(grep gfxplugin\  "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt")"; echo "launcher : $(pgrep -c retrobpi_launcher) proc"; echo "retroarch: $(pgrep -c retroarch) proc"' 2>&1 | grep -vi warning
