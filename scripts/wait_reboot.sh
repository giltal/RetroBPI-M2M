#!/bin/bash
# Detect an ACTUAL reboot: wait for uptime to go backwards, not just for SSH to answer.
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
BEFORE=$(ssh $O root@$B 'cut -d. -f1 /proc/uptime' 2>/dev/null | tr -d '[:space:]')
[ -z "$BEFORE" ] && BEFORE=999999
echo "uptime before: ${BEFORE}s - waiting for it to drop (a real reboot)"
for i in $(seq 1 90); do
  NOW=$(ssh $O root@$B 'cut -d. -f1 /proc/uptime' 2>/dev/null | tr -d '[:space:]')
  if [ -n "$NOW" ] && [ "$NOW" -lt "$BEFORE" ]; then
    echo "REBOOTED - uptime now ${NOW}s"
    ssh $O root@$B 'echo "kernel      : $(uname -r)"
      echo "zImage md5  : $(md5sum /boot/zImage | cut -d" " -f1)"
      echo "cmdline     : $(cat /proc/cmdline)"
      echo "--- fbcon ---"
      echo "sysfs rotate: $(cat /sys/class/graphics/fbcon/rotate 2>/dev/null || echo "(absent)")"
      echo "--- did the kernel accept the option? ---"
      dmesg 2>/dev/null | grep -i "fbcon\|rotat" | head -5 || echo "  (no fbcon lines in dmesg)"
      echo "--- system ---"
      echo "launcher    : $(ps w | grep retrobpi_launcher | grep -v grep | wc -l) proc"
      echo "governor    : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
      echo "N64 res     : $(grep -h "^parallel-n64-screensize" "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt")"' 2>&1 | grep -vi warning
    exit 0
  fi
  sleep 5
done
echo "no reboot detected in 7.5 min (board still at ${NOW}s uptime)"
exit 1
