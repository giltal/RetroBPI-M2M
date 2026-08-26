import io, glob, os
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]

# ---- 1. core audio backend: native 48 kHz + better resampler quality ----
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

C = []
A = C.append
A('')
A('/* RetroBPI audio fixes. Two separate defects, both measured.')
A(' *')
A(' * (1) CLIPPING. During real gameplay the output pinned at full scale for')
A(' *     hundreds of consecutive samples (worst second: 205 clipped, peak 32768')
A(' *     = the clamp limit). Gil heard it as "a bit dirty sound". Every earlier')
A(' *     detector missed it: clipped audio is flat-topped, so there is no jump,')
A(' *     no gap, and the ALSA margin stays a healthy 96 ms.')
A(' *')
A(' *     The clamp is in convert_float_to_s16, AFTER sinc resampling. Sinc')
A(' *     overshoots on intersample peaks, so material mastered near 0 dBFS')
A(' *     exceeds full scale once resampled even with every gain stage at unity.')
A(' *     Measured overshoot: float peak reached 848 permille at 0.8 gain, i.e.')
A(' *     1060 permille (6% over) at unity. Attenuating on the way IN fixes it;')
A(' *     lowering the ALSA volume could not, because the damage happens here.')
A(' *')
A(' * (2) DOUBLE RESAMPLING. The core resampled to a hardcoded 44100 while the')
A(' *     hardware runs at 48000, so every sample went through TWO conversions:')
A(' *     32000 -> 44100 here (ratio 1.378, at RESAMPLER_QUALITY_DONTCARE) and')
A(' *     then 44100 -> 48000 in RetroArch. Targeting 48000 directly makes this')
A(' *     a single conversion at exactly 1.5 for a 32 kHz game, and lets')
A(' *     RetroArch pass the audio through untouched since it matches the card.')
A(' *     Quality is also raised off DONTCARE.')
A(' */')
A('#define AUDIO_HEADROOM_GAIN 0.8f')
A('#define AUDIO_TARGET_RATE   48000.0')
A('')
A('static void audio_probe(const float *fbuf, const int16_t *sbuf, size_t frames)')
A('{')
A('    static unsigned long nframes = 0, last = 0;')
A('    static float fpeak = 0.0f;')
A('    static int speak = 0;')
A('    static unsigned long clipped = 0;')
A('    size_t i;')
A('    FILE *f;')
A('    for (i = 0; i < frames * 2; i++) {')
A('        float a = fbuf[i] < 0.0f ? -fbuf[i] : fbuf[i];')
A('        int v = sbuf[i] < 0 ? -sbuf[i] : sbuf[i];')
A('        if (a > fpeak) fpeak = a;')
A('        if (v > speak) speak = v;')
A('        if (v >= 32700) clipped++;')
A('    }')
A('    nframes += frames;')
A('    if (nframes - last >= 48000) {')
A('        last = nframes;')
A('        f = fopen("/tmp/glitch.log", "a");')
A('        if (f) {')
A('            fprintf(f, "SEC t=%lu s16peak=%d clip=%lu float_permille=%d gain=%d' + NL + '",')
A('                    nframes / 48000, speak, clipped,')
A('                    (int)(fpeak * 1000.0f),')
A('                    (int)(AUDIO_HEADROOM_GAIN * 1000.0f));')
A('            fclose(f);')
A('        }')
A('        fpeak = 0.0f; speak = 0; clipped = 0;')
A('    }')
A('}')
A('')
helper = '\n'.join(C)

anchor = 'static void aiLenChanged(void* user_data, const void* buffer, size_t size)'
assert s.count(anchor) == 1
s = s.replace(anchor, helper + anchor)

# quality: DONTCARE -> HIGHER
old_q = 'retro_resampler_realloc(&resampler_audio_data, &resampler, "sinc", RESAMPLER_QUALITY_DONTCARE, 1.0);'
assert s.count(old_q) == 1
s = s.replace(old_q,
  'retro_resampler_realloc(&resampler_audio_data, &resampler, "sinc",\n'
  '         RESAMPLER_QUALITY_HIGHER, 1.0);')

# target 48000 instead of 44100
old_r = '   ratio             = 44100.0 / GameFreq;'
assert s.count(old_r) == 1
s = s.replace(old_r, '   ratio             = AUDIO_TARGET_RATE / GameFreq;')

old_m = '   max_frames        = (GameFreq > 44100) ? MAX_AUDIO_FRAMES : (size_t)(MAX_AUDIO_FRAMES / ratio - 1);'
assert s.count(old_m) == 1
s = s.replace(old_m,
  '   max_frames        = (GameFreq > AUDIO_TARGET_RATE)\n'
  '      ? MAX_AUDIO_FRAMES : (size_t)(MAX_AUDIO_FRAMES / ratio - 1);')

old_g = 'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2, 1.0f);'
assert s.count(old_g) == 1
s = s.replace(old_g,
  'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2,\n'
  '         AUDIO_HEADROOM_GAIN);')

old_o = '   out                    = audio_out_buffer_s16;\n'
assert s.count(old_o) == 1
s = s.replace(old_o, old_o +
  '\n   audio_probe(audio_out_buffer_float, audio_out_buffer_s16, data.output_frames);\n')

io.open(p, 'w', encoding='utf-8', newline='').write(s)

# ---- 2. libretro.c: declare 48000 so RetroArch does not resample ----
q = d + 'libretro/libretro.c'
if not os.path.exists(q + '.orig'):
    io.open(q + '.orig', 'w', encoding='utf-8', newline='').write(
        io.open(q, encoding='utf-8', newline='').read())
t = io.open(q + '.orig', encoding='utf-8', newline='').read()
old_sr = '   info->timing.sample_rate = 44100.0;'
assert t.count(old_sr) == 1
t = t.replace(old_sr,
  '   /* RetroBPI: 48000 to match the codec exactly, so RetroArch performs no\n'
  '    * rate conversion at all. The core now resamples straight to this rate. */\n'
  '   info->timing.sample_rate = 48000.0;')
io.open(q, 'w', encoding='utf-8', newline='').write(t)

c = io.open(p, encoding='utf-8', newline='').read()
print('braces balanced :', c.count('{') == c.count('}'))
print('target 48k      :', 'AUDIO_TARGET_RATE / GameFreq' in c)
print('quality HIGHER  :', 'RESAMPLER_QUALITY_HIGHER' in c)
print('headroom gain   :', 'AUDIO_HEADROOM_GAIN);' in c)
print('declared 48000  :', 'info->timing.sample_rate = 48000.0;' in t)
