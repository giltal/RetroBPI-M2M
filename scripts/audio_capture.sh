#!/bin/bash
# audio_capture.sh start|stop|fetch  -- capture the exact s16 stream from the core
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
case "${1:-start}" in
start)
  ssh $O root@$B 'rm -f /tmp/audio_dump.raw; touch /tmp/dump_on
    echo "CAPTURING - play now (auto-stops after 30 s of audio)"' 2>&1 | grep -vi warning || true
  ;;
stop)
  ssh $O root@$B 'rm -f /tmp/dump_on
    echo "stopped; captured $(wc -c < /tmp/audio_dump.raw 2>/dev/null) bytes"' 2>&1 | grep -vi warning || true
  ;;
fetch)
  ssh $O root@$B 'rm -f /tmp/dump_on' 2>&1 | grep -vi warning || true
  scp $O root@$B:/tmp/audio_dump.raw /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/audio_dump.raw 2>&1 | grep -vi warning || true
  ls -la /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/audio_dump.raw
  ;;
esac
