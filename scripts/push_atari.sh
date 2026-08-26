#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
# restore the stock retroarch binary (drop the diagnostic build)
ssh $O root@$B '[ -f /tmp/ra_orig.bin ] && cp /tmp/ra_orig.bin /usr/bin/retroarch.bin && echo "stock retroarch.bin restored"' 2>&1 | grep -vi warning || true
scp $O "$R/root/.config/retroarch/config/Atari800/Atari800.cfg" \
      "root@$B:'/root/.config/retroarch/config/Atari800/Atari800.cfg'" 2>&1 | grep -vi warning || true
ssh $O root@$B 'echo "--- on board now ---"
  grep -h "^audio_volume" "/root/.config/retroarch/config/Atari800/Atari800.cfg"
  echo "retroarch probe strings: $(strings /usr/bin/retroarch.bin | grep -c RETROBPI_AUDIO_PROBE) (0 = stock)"
  rm -f /tmp/ra_audio.log /tmp/ra_stderr.log /tmp/ra_new.bin' 2>&1 | grep -vi warning || true
