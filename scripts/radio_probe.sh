#!/bin/sh
echo "=== network interfaces ==="
ip -brief link 2>/dev/null || ifconfig -a 2>/dev/null | grep -E '^[a-z]'
echo
echo "=== is wifi up / associated? ==="
iw dev 2>/dev/null | grep -E 'Interface|ssid|channel' || echo "  (no iw)"
cat /proc/net/wireless 2>/dev/null || echo "  (no /proc/net/wireless)"
echo
echo "=== wpa_supplicant running? (background scans cause periodic TX) ==="
ps w | grep [w]pa_supplicant || echo "  not running"
echo
echo "=== bluetooth ==="
ps w | grep [b]luetoothd || echo "  bluetoothd not running"
hciconfig 2>/dev/null | head -6 || echo "  (no hciconfig)"
echo "  connected input devices:"
cat /proc/bus/input/devices 2>/dev/null | grep -E '^N:' | head -8
echo
echo "=== brcmfmac / bt module loaded ==="
lsmod 2>/dev/null | grep -iE 'brcm|bt|hci' || echo "  none listed"
echo
echo "=== interrupt counts for wifi/bt/uart (activity indicator) ==="
grep -iE 'mmc|ttyS|hci|brcm' /proc/interrupts
