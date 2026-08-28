#!/bin/bash
# Watch for the DS3 cable-pairing to complete. Reports the link key appearing on
# disk, the HID connection, and the two failure signatures -- silence must not be
# mistaken for progress.
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
ADDR=02:00:00:42:50:49
seen_usb=0; seen_key=0; seen_hid=0; seen_err=0
for i in $(seq 1 200); do
  out=$(ssh $O root@$B "sh -c '
    echo USB:\$(cat /sys/bus/usb/devices/*/product 2>/dev/null | tr \"\n\" \"|\")
    echo KEY:\$(ls /var/lib/bluetooth/$ADDR/ 2>/dev/null | grep -cE \"^[0-9A-F:]{17}\\$\")
    echo HID:\$(grep -c \"Sony PLAYSTATION\" /proc/bus/input/devices)
    echo ERR:\$(dmesg | grep -ci \"sixaxis.*failed\")
    echo AG:\$(grep -c \"without agent\" /var/log/bt-agent.log 2>/dev/null)
  '" 2>/dev/null) || { sleep 3; continue; }

  case "$(echo "$out" | sed -n 's/^USB://p')" in
    *PLAYSTATION*|*Controller*) [ $seen_usb = 0 ] && { echo "DS3 detected over USB"; seen_usb=1; };;
  esac
  k=$(echo "$out" | sed -n 's/^KEY://p')
  h=$(echo "$out" | sed -n 's/^HID://p')
  e=$(echo "$out" | sed -n 's/^ERR://p')
  a=$(echo "$out" | sed -n 's/^AG://p')
  [ "${k:-0}" -gt 0 ] && [ $seen_key = 0 ] && { echo "LINK KEY WRITTEN -- cable pairing succeeded"; seen_key=1; }
  [ "${e:-0}" -gt 0 ] && [ $seen_err = 0 ] && { echo "SIXAXIS ERROR: plugin could not write the central address"; seen_err=1; }
  [ "${a:-0}" -gt 0 ] && [ $seen_err = 0 ] && { echo "AGENT ERROR: authentication attempted with no agent"; seen_err=1; }
  [ "${h:-0}" -gt 0 ] && [ $seen_hid = 0 ] && { echo "PAD CONNECTED over Bluetooth ($h input nodes)"; seen_hid=1; }
  [ $seen_hid = 1 ] && { echo "done"; exit 0; }
  sleep 3
done
echo "timed out waiting for the pairing"
