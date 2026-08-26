#!/bin/sh
echo "=== retroarch processes ==="
ps w | grep retroarch | grep -v grep
echo "=== launcher ==="
ps w | grep retrobpi_launcher | grep -v grep
echo "=== uptime / load ==="
uptime
