#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
echo "=== the audio-list option: key and values ==="
strings "$SO" | grep -B3 -A3 'Send audio lists to HLE RSP' | head -12
echo
echo "=== all parallel-n64 keys mentioning alist / audio / rsp ==="
strings "$SO" | grep -E '^parallel-n64-' | grep -iE 'alist|audio|rsp|hle'
echo
echo "=== full key list (for context) ==="
strings "$SO" | grep -E '^parallel-n64-' | sort -u | head -30
