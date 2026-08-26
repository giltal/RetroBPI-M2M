#!/bin/bash
set -e
cd ~/bpi/buildroot
O=~/bpi/output
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
OUT=$EXT/board/bpi-m2m/patches/linux
F=drivers/input/touchscreen/edt-ft5x06.c

echo "=== extract + apply existing patches, so context matches what 0006 will see ==="
make O=$O linux-dirclean >/dev/null 2>&1
make O=$O linux-patch 2>&1 | grep -E 'Applying|ERROR' | tail -6
K=$O/build/linux-6.18.8

T=$(mktemp -d); trap 'rm -rf $T' EXIT
cp "$K/$F" "$T/orig.c"
cp "$K/$F" "$T/new.c"

python3 - "$T/new.c" <<'PYEOF'
import sys
path = sys.argv[1]
LF, CRLF = chr(10), chr(13) + chr(10)
raw = open(path, newline='').read()
nl  = CRLF if CRLF in raw else LF
lines = raw.split(nl)

# 1. remember which slots the controller reported this pass
for i, l in enumerate(lines):
    if 'int i, type, x, y, id;' in l:
        lines[i] = l + nl + '\tunsigned long seen = 0;'
        break
else:
    sys.exit('ERROR: decl anchor not found')

# 2. mark a slot as seen where it is reported
for i, l in enumerate(lines):
    if 'input_mt_slot(tsdata->input, id);' in l:
        indent = l[:len(l) - len(l.lstrip())]
        lines[i] = indent + 'seen |= 1UL << id;' + nl + l
        break
else:
    sys.exit('ERROR: input_mt_slot anchor not found')

# 3. close anything not reported -- only when polling
for i, l in enumerate(lines):
    if 'input_mt_report_pointer_emulation(tsdata->input, true);' in l:
        block = [
'',
'\t/*',
'\t * Close slots the controller stopped reporting.',
'\t *',
'\t * When a finger lifts, this controller does not report TOUCH_EVENT_UP for',
'\t * the vacated point -- it reports Reserved, which the loop above skips. In',
'\t * IRQ mode that is harmless: the controller only interrupts when there is',
'\t * something to say, so an UP arrives as its own event. Polling has no such',
'\t * guarantee. We run every EDT_FT5X06_POLL_INTERVAL_MS regardless, see',
'\t * Reserved for the lifted finger, skip it, and leave the slot open forever.',
'\t *',
'\t * The visible result is that ABS_MT_TRACKING_ID never returns to -1 and',
'\t * BTN_TOUCH never returns to 0. Because input_event() suppresses repeated',
'\t * values, BTN_TOUCH is then emitted exactly once -- on the first touch',
'\t * after boot -- and never again, so userspace sees coordinates streaming',
'\t * but no press or release. Every touch-driven UI appears completely dead.',
'\t */',
'\tif (tsdata->client->irq <= 0) {',
'\t\tfor (i = 0; i < tsdata->max_support_points; i++) {',
'\t\t\tif (seen & (1UL << i))',
'\t\t\t\tcontinue;',
'\t\t\tinput_mt_slot(tsdata->input, i);',
'\t\t\tinput_mt_report_slot_inactive(tsdata->input);',
'\t\t}',
'\t}',
'',
        ]
        lines[i:i] = block
        break
else:
    sys.exit('ERROR: pointer_emulation anchor not found')

open(path, 'w', newline='').write(nl.join(lines))
print('  edits applied')
PYEOF

cd "$T"
{
  echo "input: edt-ft5x06: release touches when polling"
  echo
  echo "The controller reports Reserved rather than TOUCH_EVENT_UP for a lifted"
  echo "finger. With an interrupt that is fine, but when polling the slot is never"
  echo "closed, so BTN_TOUCH latches at 1 and userspace never sees a press again."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  diff -u --label "a/$F" --label "b/$F" orig.c new.c || true
} > "$OUT/0006-input-edt-ft5x06-release-touches-when-polling.patch"

echo "  patch lines: $(wc -l < "$OUT/0006-input-edt-ft5x06-release-touches-when-polling.patch")"
echo "  hunks: $(grep -c '^@@' "$OUT/0006-input-edt-ft5x06-release-touches-when-polling.patch")"
