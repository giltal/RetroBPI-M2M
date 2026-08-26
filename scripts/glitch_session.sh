#!/bin/bash
# Install/remove the glitch-detecting core for a real gameplay session.
#   glitch_session.sh install | collect | restore
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
CORE=/usr/lib/libretro/paralleln64_libretro.so

case "${1:-collect}" in
install)
  RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
  [ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
  scp $O ~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so root@$B:/tmp/n64dbg.so 2>&1 | grep -vi warning || true
  # Only save a backup if the CURRENT core is clean. Running install twice used
  # to overwrite the good backup with an already-instrumented core, so restore
  # would have put instrumented code back on the board.
  ssh $O root@$B "if strings $CORE | grep -q 'glitch.log'; then
      echo 'current core is ALREADY instrumented - keeping existing backup'
    else
      cp $CORE /tmp/n64_stock.so; echo 'clean stock backed up'
    fi
    cp /tmp/n64dbg.so $CORE
    rm -f /tmp/glitch.log
    echo 'instrumented core installed; stock saved to /tmp/n64_stock.so'
    echo \"marker present: \$(strings $CORE | grep -c GLITCH)\"" 2>&1 | grep -vi warning || true
  ;;
collect)
  ssh $O root@$B 'L=/tmp/glitch.log
    [ -f $L ] || { echo "no glitch.log - was the instrumented core installed?"; exit 1; }
    echo "=== discrete glitch events (jump > 12000) ==="
    grep "^GLITCH" $L | head -30
    echo "  total: $(grep -c "^GLITCH" $L)"
    echo
    echo "=== per-second peak jump: normal range vs outliers ==="
    grep "^SEC" $L | sed -n "s/.*maxjump=\([0-9]*\).*/\1/p" | sort -n | tail -15 | sed "s/^/  peak /"
    echo "  seconds recorded: $(grep -c "^SEC" $L)"
    echo
    echo "=== timeline: last 20 seconds ==="
    grep "^SEC" $L | tail -20' 2>&1 | grep -vi warning || true
  ;;
restore)
  RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
  [ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
  ssh $O root@$B "[ -f /tmp/n64_stock.so ] && cp /tmp/n64_stock.so $CORE
    echo \"restored; instrumentation markers now: \$(strings $CORE | grep -c GLITCH)\"" 2>&1 | grep -vi warning || true
  ;;
esac
