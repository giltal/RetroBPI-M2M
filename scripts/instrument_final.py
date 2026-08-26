import io, glob, os
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
s = io.open(p + '.orig', encoding='utf-8', newline='').read()   # always from pristine

C = []
A = C.append
A('')
A('/* RetroBPI: input headroom to stop the resampler clipping.')
A(' *')
A(' * MEASURED during real gameplay: the output pinned at full scale for hundreds')
A(' * of consecutive samples (worst second: 205 clipped, peak 32768 = the clamp')
A(' * limit), while ordinary seconds peaked around 22000-30000. Gil described it')
A(' * as "a bit dirty sound" -- distortion, not a click. Earlier detectors all')
A(' * missed it because clipped audio is flat-topped: no jump, no gap, and the')
A(' * ALSA margin stayed a healthy 96 ms throughout.')
A(' *')
A(' * The clamp happens in convert_float_to_s16 AFTER sinc resampling. Sinc')
A(' * overshoots on intersample peaks, so material mastered near 0 dBFS -- which')
A(' * N64 audio generally is -- exceeds full scale once resampled, even with every')
A(' * gain stage at unity (both digital mixer controls measured at exactly 0 dB).')
A(' * Turning down the ALSA volume cannot fix this; the damage is already done')
A(' * inside the core, so it would only make the distortion quieter.')
A(' *')
A(' * Therefore attenuate on the way IN, before the resampler. 0.8 = -1.94 dB.')
A(' * Compensate with the analog headphone control (measured at 45 of 63).')
A(' */')
A('#define AUDIO_HEADROOM_GAIN 0.8f')
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
A('    if (nframes - last >= 44100) {')
A('        last = nframes;')
A('        f = fopen("/tmp/glitch.log", "a");')
A('        if (f) {')
A('            fprintf(f, "SEC t=%lu s16peak=%d clip=%lu float_permille=%d gain=%d' + NL + '",')
A('                    nframes / 44100, speak, clipped,')
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
c = io.open(p, encoding='utf-8', newline='').read()
print('braces balanced :', c.count('{') == c.count('}'), c.count('{'), c.count('}'))
print('gain applied    :', 'AUDIO_HEADROOM_GAIN);' in c)
print('probe calls     :', c.count('audio_probe('))
i = c.find('gain=%d')
print('newline literal :', repr(c[i + 7:i + 11]))
