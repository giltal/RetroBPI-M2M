#!/bin/sh
BOARD=${BOARD:-10.100.102.76}
ssh -o ConnectTimeout=6 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$BOARD \
  'echo "HOST: $(hostname)"; uname -a; echo "--- uptime ---"; uptime; echo "--- ip ---"; ip -4 addr show | grep inet; echo "--- retroarch running? ---"; ps w | grep -c "[r]etroarch"; echo "--- launcher? ---"; ps w | grep -c "[r]etrobpi_launcher"' 2>&1 | head -25
