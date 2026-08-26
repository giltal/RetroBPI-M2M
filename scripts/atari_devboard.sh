#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'grep -rn "libretro_device" /root/.config/retroarch/retroarch.cfg /root/.config/retroarch/config/Atari800/* 2>/dev/null | head; ls /root/.config/retroarch/config/remaps/ 2>/dev/null' 2>&1 | grep -vi warning
