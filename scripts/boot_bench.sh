#!/bin/bash
# Reboot the board N times and report boot metrics per run.
#
# Repeats are not optional on this board: the DevelopmentLog records ~+/-1.5 s
# run-to-run spread on SD-backed boots, which is larger than most wins being
# claimed. Two earlier "conclusions" in this project were single-run artefacts.
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
N=${1:-3}
LABEL=${2:-run}

echo "=== $LABEL: $N boots ==="
printf "  %-5s %8s %8s %8s %8s %8s\n" "#" "crng" "udev" "launch" "ready" "rcSend"
for n in $(seq 1 $N); do
  ssh $O root@$B '(sleep 1; reboot) >/dev/null 2>&1 &' >/dev/null 2>&1
  sleep 12
  ok=0
  for i in $(seq 1 40); do
    if ssh $O root@$B 'test -s /var/log/retrobpi_launcher.log' >/dev/null 2>&1; then ok=1; break; fi
    sleep 2
  done
  [ "$ok" = "1" ] || { printf "  %-5s  UNREACHABLE\n" "$n"; continue; }
  ssh $O root@$B 'sh -s' 2>/dev/null <<'RMT'
crng=$(dmesg | sed -n 's/^\[ *\([0-9.]*\)\] random: crng init done.*/\1/p' | head -1)
udev=$(awk '$1=="S10udevd"{printf "%.2f", $3-$2}' /run/boottiming)
lt0=$(awk '$1=="S12launcher"{printf "%.2f", $2}' /run/boottiming)
rcs=$(awk '$1=="end"{printf "%.2f", $2}' /run/boottiming)
rdy=$(sed -n 's/.*ready in \([0-9]*\) ms.*/\1/p' /var/log/retrobpi_launcher.log | head -1)
ui=$(awk -v a="$lt0" -v b="$rdy" 'BEGIN{printf "%.2f", a + b/1000}')
echo "$crng $udev $lt0 $ui $rcs"
RMT
done | awk -v n=0 '
  /UNREACHABLE/ {print; next}
  NF==5 {n++; printf "  %-5s %8s %8s %8s %8s %8s\n", n, $1, $2, $3, $4, $5;
         c+=$1; u+=$2; l+=$3; r+=$4; e+=$5; k++}
  END { if(k) printf "  %-5s %8.2f %8.2f %8.2f %8.2f %8.2f   <- mean of %d\n","mean",c/k,u/k,l/k,r/k,e/k,k }'
