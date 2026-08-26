#!/bin/sh
# Run ON THE BOARD. Tests whether angrylion's vi_process_fast path presents
# frames when vi_process_full does not.
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
VBL=/proc/interrupts
PCM=/proc/asound/card0/pcm0p/sub0/status
WINDOW=6

[ -f "$ROM" ] || { echo "NO ROM"; exit 1; }
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch already running"; exit 2; fi

cp "$OPT" /tmp/n64.opt.bak

vbl_count() { awk '/1c0c000.lcd-controller/{print $2}' $VBL; }
hw_ptr()    { awk -F': *' '/hw_ptr/{print $2}' $PCM 2>/dev/null; }

run_case() {
  NAME="$1"; GFX="$2"; VIO="$3"
  # rewrite the opt file
  sed -i "s/^parallel-n64-gfxplugin = .*/parallel-n64-gfxplugin = \"$GFX\"/" "$OPT"
  sed -i "/^parallel-n64-angrylion-vioverlay/d" "$OPT"
  [ -n "$VIO" ] && echo "parallel-n64-angrylion-vioverlay = \"$VIO\"" >> "$OPT"

  retroarch -L "$CORE" "$ROM" > /tmp/ra_$NAME.log 2>&1 &
  RAPID=$!
  sleep 5                       # let it boot and settle
  V0=$(vbl_count); A0=$(hw_ptr)
  sleep $WINDOW
  V1=$(vbl_count); A1=$(hw_ptr)
  CPU=$(top -b -n1 2>/dev/null | awk '/retroarch/{print $7; exit}')
  kill $RAPID 2>/dev/null; sleep 2; kill -9 $RAPID 2>/dev/null; sleep 1

  [ -z "$A0" ] && A0=0; [ -z "$A1" ] && A1=0
  DV=$((V1-V0)); DA=$((A1-A0))
  printf '%-34s vblanks+%-6s fps=%-5s audio+%-8s cpu=%s\n' \
     "$NAME" "$DV" "$((DV/WINDOW))" "$DA" "$CPU"
}

echo "=== window ${WINDOW}s; full-speed audio = 264600 ==="
run_case "rice (control)"            "rice"      ""
run_case "angrylion Filtered(full)"  "angrylion" "Filtered"
run_case "angrylion Unfiltered(fast)" "angrylion" "Unfiltered"
run_case "angrylion Depth(fast)"     "angrylion" "Depth"
run_case "angrylion Coverage(fast)"  "angrylion" "Coverage"

cp /tmp/n64.opt.bak "$OPT"
echo "=== opt restored ==="
