F=~/bpi/output/target/usr/bin/retroarch
echo "=== audio drivers compiled into retroarch ==="
strings $F | grep -xE "alsa|alsathread|oss|pulse|sdl2|tinyalsa|null|jack|rsound" | sort -u
echo "=== rate control / audio knobs present ==="
strings $F | grep -xE "audio_rate_control_delta|audio_rate_control|audio_max_timing_skew|audio_block_frames|audio_sync|audio_driver" | sort -u
echo "=== current cfg audio settings ==="
grep -E "^audio_" /mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay/root/.config/retroarch/retroarch.cfg
