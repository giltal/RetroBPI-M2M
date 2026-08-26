import io, re, sys
P = sys.argv[1] if len(sys.argv) > 1 else \
    "buildroot-external/board/bpi-m2m/patches/linux/0002-arm-dts-bananapi-m2m-panels.patch"
s = io.open(P, encoding="utf-8", newline="").read().replace(chr(13), "")
if s.endswith(chr(10)):
    s = s[:-1]                      # the trailing newline is not a hunk line
lines = s.split(chr(10))
hunk_re = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
bad = tot = 0
cur = curhdr = None
old_n = new_n = 0
def close():
    global bad
    if cur:
        eo, en = cur
        if (eo, en) != (old_n, new_n):
            print("  MISMATCH %s: header -%d +%d, counted -%d +%d" % (curhdr, eo, en, old_n, new_n))
            bad += 1
for ln in lines:
    m = hunk_re.match(ln)
    if m:
        close(); tot += 1
        curhdr = ln
        cur = (int(m.group(2) or 1), int(m.group(4) or 1))
        old_n = new_n = 0
    elif cur is not None:
        # file headers MUST be tested first: "--- /dev/null" starts with "-"
        # and "+++ b/path" starts with "+", so testing +/- first counts them
        # as diff lines and every new-file hunk looks off by one.
        if ln.startswith("diff ") or ln.startswith("--- ") or ln.startswith("+++ "):
            close(); cur = None
        elif ln.startswith("+"): new_n += 1
        elif ln.startswith("-"): old_n += 1
        else:                    old_n += 1; new_n += 1   # context (incl. bare "")
close()
print("%d hunks checked: %s" % (tot, "ALL CONSISTENT" if bad == 0 else "%d BAD" % bad))
