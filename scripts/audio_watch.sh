#!/bin/sh
# READ-ONLY audio health watcher. Safe to run while a game is being played.
#
# The earlier metric (hw_ptr going backwards) only sees a FULL underrun, after
# the card has already starved and the stream was re-prepared. Audible ticks
# happen on near-misses that leave no trace there. This watches the margin.
#
# Fields the kernel already exposes per substream (no computation needed):
#   delay      - frames queued ahead of the card. This IS the safety margin.
#   avail      - free space in the buffer (buffer_size - delay)
#   avail_max  - NOT USABLE on this driver. It was expected to be a persistent
#                high-water mark, but measurement shows it oscillates and
#                resets continuously (4608 -> 1512 -> 136 -> 72 inside one
#                second), so tracking its rises produced ~15000 spurious
#                events in 25 s. Ignored entirely. The earlier claim that it
#                'cannot miss an event' was simply wrong.
#
# What IS trustworthy:
#   delay      - the margin, sampled at ~700 Hz. A real collapse lasts far
#                longer than 1.4 ms, so sampling does catch it.
#   hw_ptr going backwards - an unambiguous full underrun.
#
# Note the status file pads keys before the colon ("hw_ptr      : 123"), so the
# key must be trimmed before matching -- getting this wrong silently collected
# zero samples on the first attempt.
#
# The loop deliberately uses NO subprocesses: an earlier version called
# $(cut -d. -f1 /proc/uptime) in the while condition, forking ~112 times a
# second, which is real load on a 1.2 GHz A7 and could perturb the very timing
# margin being measured. /proc/uptime is read with the read builtin instead.

ST=/proc/asound/card0/pcm0p/sub0/status
HWP=/proc/asound/card0/pcm0p/sub0/hw_params
OUT=${1:-/tmp/audio_watch.log}
DUR=${2:-600}

BUFSZ=$(awk -F': *' '/^buffer_size/{print $2}' $HWP 2>/dev/null)
PERIOD=$(awk -F': *' '/^period_size/{print $2}' $HWP 2>/dev/null)
RATE=$(awk -F'[: ]+' '/^rate/{print $2}' $HWP 2>/dev/null)
: ${BUFSZ:=6144}; : ${PERIOD:=1536}; : ${RATE:=48000}
# Warn at TWO periods, not one. Healthy margin measured in-game is ~119 ms; by
# the time only one period (32 ms) is left the tick has effectively happened.
# Warning earlier shows the margin eroding on the way down.
WARN=$((PERIOD*2))

{
  echo "# buffer_size=$BUFSZ period_size=$PERIOD rate=$RATE"
  echo "# warn when delay < $WARN frames ($((WARN*1000/RATE)) ms queued)"
  echo "# columns: uptime delay_frames delay_ms state"
} > "$OUT"

MIN=99999999; SAMPLES=0; DIPS=0; RESETS=0; LASTHW=0
BUCKET=""; BMIN=99999999
read up _ < /proc/uptime; START=${up%.*}
END=$(( START + DUR ))
NOW=$START

while [ "$NOW" -lt "$END" ]; do
  read up _ < /proc/uptime; NOW=${up%.*}
  st=""; dly=""; hw=""
  while IFS=':' read -r k v; do
    k=${k%% *}                       # trim padding before the colon
    v=${v# }
    case "$k" in
      state)     st=$v ;;
      delay)     dly=$v ;;
      hw_ptr)    hw=$v ;;
    esac
  done < "$ST" 2>/dev/null

  [ -z "$dly" ] && continue
  [ "$st" != "RUNNING" ] && continue
  SAMPLES=$((SAMPLES+1))

  [ -n "$hw" ] && [ "$hw" -lt "$LASTHW" ] && {
    RESETS=$((RESETS+1))
    echo "$NOW RESET hw_ptr $LASTHW -> $hw" >> "$OUT"
  }
  [ -n "$hw" ] && LASTHW=$hw

  # per-bucket minimum margin, so the trend is visible even with no dips at all
  if [ "$NOW" != "$BUCKET" ]; then
    [ -n "$BUCKET" ] && [ "$BMIN" -lt 99999999 ] &&       echo "$BUCKET MIN $BMIN $((BMIN*1000/RATE))ms" >> "$OUT"
    BUCKET=$NOW; BMIN=99999999
  fi
  [ "$dly" -lt "$BMIN" ] && BMIN=$dly

  [ "$dly" -lt "$MIN" ] && MIN=$dly
  if [ "$dly" -lt "$WARN" ]; then
    DIPS=$((DIPS+1))
    echo "$NOW $dly $((dly*1000/RATE)) $st" >> "$OUT"
  fi
done

[ $SAMPLES -eq 0 ] && MIN=0
{
  echo "# ---- summary ----"
  echo "# samples          : $SAMPLES"
  echo "# min delay        : $MIN frames ($((MIN*1000/RATE)) ms queued at worst)"
  echo "# dips below 1 period : $DIPS"
  echo "# full resets      : $RESETS"
} >> "$OUT"
echo "watcher done -> $OUT  (samples=$SAMPLES dips=$DIPS resets=$RESETS)"
