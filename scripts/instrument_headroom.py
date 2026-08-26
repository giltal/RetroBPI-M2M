import io, glob, os
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

helper = (
'\n/* RetroBPI: input headroom to stop the resampler clipping.\n'
' *\n'
' * MEASURED: during real gameplay the output pinned at full scale for hundreds\n'
' * of consecutive samples (worst second: 205 clipped samples, peak 32768 =\n'
' * the clamp limit) while quiet seconds peaked around 22000-30000. Gil describes\n'
' * it as "a bit dirty sound" -- distortion, not a click. Every earlier detector\n'
' * missed it because clipped audio is flat-topped: no jump, no gap, and the ALSA\n'
' * margin stays a healthy 96 ms throughout.\n'
' *\n'
' * The clamp happens in convert_float_to_s16 AFTER sinc resampling. Sinc\n'
' * overshoots on intersample peaks, so material mastered near 0 dBFS -- which\n'
' * N64 game audio generally is -- exceeds full scale once resampled, even with\n'
' * every gain stage at unity (both digital mixer controls measured at exactly\n'
' * 0 dB). Lowering the ALSA volume cannot fix this; it would only make the\n'
' * distortion quieter, because the damage is already done inside the core.\n'
' *\n'
' * So attenuate on the way IN, before the resampler, leaving room for overshoot.\n'
' * AUDIO_HEADROOM_GAIN 0.8 = -1.94 dB. Compensate with the analog headphone\n'
' * control, which has plenty of range left (measured at 45 of 63).\n'
' */\n'
'#define AUDIO_HEADROOM_GAIN 0.8f\n'
'\n'
'/* Reports how far the resampler output would have gone past full scale if it\n'
' * were not clamped, in permille (1000 = exactly 0 dBFS). This says how much\n'
' * headroom is actually required rather than leaving it to guesswork. */\n'
'static void headroom_scan(const float *buf, size_t frames)\n'
'{\n'
'    static unsigned long nframes = 0, last = 0;\n'
'    static float peak = 0.0f;\n'
'    size_t i;\n'
'    FILE *f;\n'
'    for (i = 0; i < frames * 2; i++) {\n'
'        float a = buf[i] < 0.0f ? -buf[i] : buf[i];\n'
'        if (a > peak) peak = a;\n'
'    }\n'
'    nframes += frames;\n'
'    if (nframes - last >= 44100) {\n'
'        last = nframes;\n'
'        f = fopen("/tmp/glitch.log", "a");\n'
'        if (f) {\n'
'            fprintf(f, "HEAD t=%lu float_peak_permille=%d gain=%d' + NL + '",\n'
'                    nframes/44100, (int)(peak * 1000.0f),\n'
'                    (int)(AUDIO_HEADROOM_GAIN * 1000.0f));\n'
'            fclose(f);\n'
'        }\n'
'        peak = 0.0f;\n'
'    }\n'
'}\n'
)

# keep the clip/peak detector too
old_helper_anchor = 'static void aiLenChanged(void* user_data, const void* buffer, size_t size)'
clip = io.open('scripts/instrument_clip.py', encoding='utf-8').read()
# reuse the clip scanner verbatim from the previous instrumentation
start = clip.index("'static void glitch_scan")
end = clip.index("'\n)", start)
scan = clip[start:end]
scan = scan.replace("'", '', 1)
scan_lines = []
for ln in scan.split("\n"):
    ln = ln.strip()
    if ln.startswith("'"):
        ln = ln[1:]
    if ln.endswith("'"):
        ln = ln[:-1]
    ln = ln.replace(BS + "n' +" , '').replace("' + NL + '", NL)
    scan_lines.append(ln)
scanner = "\n".join(scan_lines)

s = s.replace(old_helper_anchor, helper + scanner + '\n\n' + old_helper_anchor)

# apply the headroom gain on input
old_g = 'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2, 1.0f);'
assert s.count(old_g) == 1
s = s.replace(old_g,
  'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2,\n'
  '         AUDIO_HEADROOM_GAIN);')

old_o = '   out                    = audio_out_buffer_s16;\n'
assert s.count(old_o) == 1
s = s.replace(old_o, old_o +
  '\n   headroom_scan(audio_out_buffer_float, data.output_frames);\n'
  '   glitch_scan(audio_out_buffer_s16, data.output_frames);\n')

io.open(p,'w',encoding='utf-8',newline='').write(s)
c = io.open(p, encoding='utf-8', newline='').read()
print('gain applied     :', 'AUDIO_HEADROOM_GAIN);' in c)
print('headroom_scan    :', c.count('headroom_scan('))
print('glitch_scan      :', c.count('glitch_scan('))
i = c.find('gain=%d')
print('newline literal  :', repr(c[i+7:i+11]))
