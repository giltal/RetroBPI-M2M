import io, glob, os
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

C = []; A = C.append
A('')
A('/* RetroBPI audio work. Established by measurement, in order:')
A(' *   - delivery is perfect (sample count and rate exact, ALSA margin 96 ms)')
A(' *   - no clicks (zero sample-to-sample discontinuities)')
A(' *   - CLIPPING was real: 436 samples pinned at full scale in one session.')
A(' *     Fixed by attenuating before the resampler; the clamp is downstream in')
A(' *     convert_float_to_s16, so ALSA volume could never have fixed it.')
A(' *   - still dirty afterwards, so a second defect exists.')
A(' *')
A(' * Now targeting the resampling chain: output 48000 natively (one conversion')
A(' * at exactly 1.5 for a 32 kHz game, instead of 32000->44100->48000 with the')
A(' * first stage at RESAMPLER_QUALITY_DONTCARE), and raise quality.')
A(' *')
A(' * The dump below writes the exact s16 stream handed to the frontend, so the')
A(' * waveform can be analysed directly rather than through a speaker and a mic.')
A(' */')
A('#define AUDIO_HEADROOM_GAIN 0.8f')
A('#define AUDIO_TARGET_RATE   48000.0')
A('#define AUDIO_DUMP_MAX      (48000 * 30 * 2)   /* 30 s stereo, ~5.8 MB */')
A('')
A('static void audio_probe(const float *fbuf, const int16_t *sbuf, size_t frames)')
A('{')
A('    static unsigned long nframes = 0, last = 0;')
A('    static float fpeak = 0.0f;')
A('    static int speak = 0;')
A('    static unsigned long clipped = 0;')
A('    static unsigned long dumped = 0;')
A('    static FILE *dump = NULL;')
A('    size_t i;')
A('    FILE *f;')
A('    for (i = 0; i < frames * 2; i++) {')
A('        float a = fbuf[i] < 0.0f ? -fbuf[i] : fbuf[i];')
A('        int v = sbuf[i] < 0 ? -sbuf[i] : sbuf[i];')
A('        if (a > fpeak) fpeak = a;')
A('        if (v > speak) speak = v;')
A('        if (v >= 32700) clipped++;')
A('    }')
A('    /* capture the raw stream while the trigger file exists */')
A('    if (dumped < AUDIO_DUMP_MAX) {')
A('        f = fopen("/tmp/dump_on", "r");')
A('        if (f) {')
A('            fclose(f);')
A('            if (!dump) dump = fopen("/tmp/audio_dump.raw", "wb");')
A('            if (dump) {')
A('                fwrite(sbuf, sizeof(int16_t), frames * 2, dump);')
A('                fflush(dump);')
A('                dumped += frames * 2;')
A('            }')
A('        }')
A('    } else if (dump) { fclose(dump); dump = NULL; }')
A('    nframes += frames;')
A('    if (nframes - last >= 48000) {')
A('        last = nframes;')
A('        f = fopen("/tmp/glitch.log", "a");')
A('        if (f) {')
A('            fprintf(f, "SEC t=%lu s16peak=%d clip=%lu float_permille=%d dumped=%lu' + NL + '",')
A('                    nframes / 48000, speak, clipped,')
A('                    (int)(fpeak * 1000.0f), dumped);')
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

old_q = 'retro_resampler_realloc(&resampler_audio_data, &resampler, "sinc", RESAMPLER_QUALITY_DONTCARE, 1.0);'
assert s.count(old_q) == 1
s = s.replace(old_q, 'retro_resampler_realloc(&resampler_audio_data, &resampler, "sinc",\n         RESAMPLER_QUALITY_HIGHER, 1.0);')

old_r = '   ratio             = 44100.0 / GameFreq;'
assert s.count(old_r) == 1
s = s.replace(old_r, '   ratio             = AUDIO_TARGET_RATE / GameFreq;')

old_m = '   max_frames        = (GameFreq > 44100) ? MAX_AUDIO_FRAMES : (size_t)(MAX_AUDIO_FRAMES / ratio - 1);'
assert s.count(old_m) == 1
s = s.replace(old_m, '   max_frames        = (GameFreq > AUDIO_TARGET_RATE)\n      ? MAX_AUDIO_FRAMES : (size_t)(MAX_AUDIO_FRAMES / ratio - 1);')

old_g = 'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2, 1.0f);'
assert s.count(old_g) == 1
s = s.replace(old_g, 'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2,\n         AUDIO_HEADROOM_GAIN);')

old_o = '   out                    = audio_out_buffer_s16;\n'
assert s.count(old_o) == 1
s = s.replace(old_o, old_o + '\n   audio_probe(audio_out_buffer_float, audio_out_buffer_s16, data.output_frames);\n')

io.open(p, 'w', encoding='utf-8', newline='').write(s)
c = io.open(p, encoding='utf-8', newline='').read()
print('braces balanced:', c.count('{') == c.count('}'))
print('dump present   :', 'audio_dump.raw' in c)
print('48k target     :', 'AUDIO_TARGET_RATE / GameFreq' in c)
print('quality HIGHER :', 'RESAMPLER_QUALITY_HIGHER' in c)
