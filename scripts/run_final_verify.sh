#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
scp $O "$R/etc/init.d/S05powercap" root@$B:/etc/init.d/S05powercap 2>&1 | grep -vi warning
# remote path contains spaces: quote it for the REMOTE shell too
scp $O "$R/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg" \
    "root@$B:'/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg'" 2>&1 | grep -vi warning
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/final_verify_board.sh root@$B:/tmp/fv.sh 2>&1 | grep -vi warning
ssh $O root@$B 'ls -la "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg" && echo "--- content ---" && grep audio_latency "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg"' 2>&1 | grep -vi warning
ssh $O root@$B "sed -i \"s/\r\$//\" /etc/init.d/S05powercap /tmp/fv.sh; chmod +x /etc/init.d/S05powercap; sh /tmp/fv.sh" 2>&1 | grep -vi warning
