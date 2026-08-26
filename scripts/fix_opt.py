import io, re
p = 'buildroot-external/board/bpi-m2m/rootfs_overlay/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt'
s = io.open(p, encoding='utf-8', newline='').read()

s = s.replace('parallel-n64-screensize = "640x480"',
              'parallel-n64-screensize = "320x240"')

# Replace the whole stale "measured as NOT helping" block, which is wrong.
old = re.search(r'# Things measured as NOT helping:.*?framerate=fullspeed \(worse\)\.', s, re.S)
assert old, 'stale block not found'
new = '''# ---------------------------------------------------------------------------
# 320x240 IS THE FIX FOR THE N64 AUDIO. Do not raise it without re-measuring.
#
# An earlier version of this file recorded 320x240 as "measured as NOT helping".
# That was wrong, and wrong in an instructive way: it had been measured against
# ALSA xrun counts, taken during 45 seconds of the title screen. Wrong metric,
# wrong load.
#
# The real metric is emulation speed -- audio-seconds produced per wall-second,
# measured during actual racing (the attract-mode demo works for automation).
# Measured that way:
#
#   rice 640x480 original     avg speed 809/1000   worst 757
#   rice 320x240 original     avg speed 998/1000   worst 943   <- shipped
#   glide64 640x480 original  avg speed 803/1000   worst 324
#   rice 640x480 fullspeed    avg speed 814/1000   worst 769
#
# At 640x480 the emulator ran at 87% of real time. The frontend's dynamic rate
# control then STRETCHES the audio to keep the ALSA buffer full, so the buffer
# looks perfect (rock steady 96 ms margin, zero underruns, zero discontinuities)
# while the stretch ratio modulates 0.85-1.10 second to second. That modulation
# is what was audible as "dirty". Gil identified the cause from experience after
# several rounds of instrumentation had reported the audio pipeline healthy.
#
# 320x240 is the N64's native output resolution, so this is not rendering below
# the original hardware -- 640x480 was 2x supersampling, an enhancement this SoC
# cannot afford. The emulator blocks ~12% of the time waiting on the Mali (it
# sits at 88% CPU, not 100%), i.e. this is GPU-bound, not CPU-bound.
#
# Beware any metric that a control loop exists to stabilise. Buffer level under
# dynamic rate control is the type case: measure what the loop sacrifices
# (timing fidelity), not what it protects.
#
# Also measured as NOT helping: send_allist_to_hle_rsp (either way),
# audio-buffer-size 2048 vs 4096, video_threaded (worse -- adds a copy when the
# problem is render throughput), framerate=fullspeed (no change, 814 vs 809).
# ---------------------------------------------------------------------------'''
s = s[:old.start()] + new + s[old.end():]
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('opt updated')
print('screensize now:', [l for l in s.split('\n') if l.startswith('parallel-n64-screensize')])
