#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'for d in psx nes snes gba genesis n64; do echo "$d: $(ls /opt/roms/$d 2>/dev/null | head -1)"; done' 2>&1 | grep -vi warning
