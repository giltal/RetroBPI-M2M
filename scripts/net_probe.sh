#!/bin/sh
echo "=== interfaces ==="
ifconfig -a 2>/dev/null | grep -E '^[a-z]|inet ' | head -12
echo
echo "=== what starts networking today ==="
cat /etc/network/interfaces 2>/dev/null
echo
echo "=== wifi init script ==="
ls -la /etc/init.d/S49wifi 2>/dev/null && head -40 /etc/init.d/S49wifi 2>/dev/null
echo
echo "=== wifi firmware present? ==="
ls /lib/firmware/brcm/ 2>/dev/null | head
echo
echo "=== is wlan0 usable right now? ==="
ip link show wlan0 2>/dev/null || ifconfig wlan0 2>/dev/null | head -3
echo "wpa_supplicant binary: $(command -v wpa_supplicant || echo MISSING)"
echo "wpa_supplicant running: $(ps w | grep [w]pa_supplicant | wc -l)"
echo "udhcpc binary: $(command -v udhcpc || echo MISSING)"
echo
echo "=== saved wifi credentials? ==="
ls -la /etc/wpa_supplicant.conf /etc/wpa_supplicant/*.conf 2>/dev/null || echo "  none on disk"
