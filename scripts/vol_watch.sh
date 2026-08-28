#!/bin/bash
# Sample the mixer + state.txt once a second and report every CHANGE, so we can
# see exactly when and to what the volume moves as a game is launched normally.
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
prev=""
echo "watching... enter a game now (Ctrl-C not needed, it stops after 180 samples)"
for i in $(seq 1 180); do
  line=$(ssh $O root@$B "sh -c '
    echo IDX=\$(amixer -c 0 cget name=\"Headphone Playback Volume\" | sed -n \"s/.*: values=\([0-9]*\).*/\1/p\" | head -1)
    echo SW=\$(amixer -c 0 cget name=\"Headphone Playback Switch\" | sed -n \"s/.*: values=//p\" | head -1)
    echo ST=\$(sed -n \"s/^volume=//p\" /opt/roms/_system/state.txt)
    echo RA=\$(ps w | grep -c \"[r]etroarch\")
  '" 2>/dev/null | tr '\n' ' ')
  [ -z "$line" ] && { sleep 1; continue; }
  if [ "$line" != "$prev" ]; then
    echo "  t=${i}s  $line"
    prev="$line"
  fi
  sleep 1
done
echo "done"
