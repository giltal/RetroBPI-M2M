import io, glob, os
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/retroarch-*'))[0]
p = d + '/audio/audio_driver.c'
orig = p + '.orig'
if not os.path.exists(orig):
    io.open(orig,'w',encoding='utf-8',newline='').write(
        io.open(p,encoding='utf-8',newline='').read())
s = io.open(orig, encoding='utf-8', newline='').read()

C = []; A = C.append
A('')
A('/* RetroBPI diagnostic: measure the audio actually handed to the driver.')
A(' *')
A(' * Sits immediately after convert_float_to_s16, which is where clamping')
A(' * happens, and therefore sees the true peak and any clipped samples AFTER')
A(' * audio_volume has been applied. Central to RetroArch, so it works for every')
A(' * core -- unlike the earlier probe, which lived inside the N64 core.')
A(' *')
A(' * Purpose: the Atari 800 per-core audio_volume is +9 dB, and its own comment')
A(' * admits nobody metered the core. This says whether that boost drives POKEY')
A(' * output into the clamp, and what the largest safe gain would be.')
A(' */')
A('static void retrobpi_audio_probe(const int16_t *buf, size_t samples, float gain)')
A('{')
A('    static unsigned long total = 0, last = 0, clipped = 0;')
A('    static int peak = 0;')
A('    size_t i;')
A('    FILE *f;')
A('    const char *env;')
A('    if (!buf || !samples)')
A('        return;')
A('    env = getenv("RETROBPI_AUDIO_PROBE");')
A('    if (!env || env[0] != Q1Q)')
A('        return;')
A('    for (i = 0; i < samples; i++)')
A('    {')
A('        int v = buf[i] < 0 ? -buf[i] : buf[i];')
A('        if (v > peak)     peak = v;')
A('        if (v >= 32700)   clipped++;')
A('    }')
A('    total += samples;')
A('    if (total - last >= 96000)   /* ~1 s of stereo at 48 kHz */')
A('    {')
A('        last = total;')
A('        f = fopen("/tmp/ra_audio.log", "a");')
A('        if (f)')
A('        {')
A('            /* headroom_permille: how close the peak is to full scale.')
A('             * 1000 = exactly at the clamp. */')
A('            fprintf(f, "AUD peak=%d headroom_permille=%d clip=%lu gain=%d' + NL + '",')
A('                    peak, (int)((peak * 1000L) / 32767), clipped,')
A('                    (int)(gain * 1000.0f));')
A('            fclose(f);')
A('        }')
A('        peak = 0; clipped = 0;')
A('    }')
A('}')
A('')
helper = '\n'.join(C).replace('Q1Q', "'1'")

anchor = 'static void audio_driver_flush('
assert s.count(anchor) == 1
s = s.replace(anchor, helper + anchor)

old = '''         convert_float_to_s16(audio_st->output_samples_conv_buf,
               (const float*)output_data, output_frames * 2);
'''
assert s.count(old) == 1
s = s.replace(old, old +
  '\n         retrobpi_audio_probe(audio_st->output_samples_conv_buf,\n'
  '               output_frames * 2, audio_st->volume_gain);\n')

io.open(p,'w',encoding='utf-8',newline='').write(s)
c = io.open(p, encoding='utf-8', newline='').read()
print('braces balanced :', c.count('{') == c.count('}'))
print('probe inserted  :', c.count('retrobpi_audio_probe('))
print('gated by env    :', 'RETROBPI_AUDIO_PROBE' in c)
i = c.find('gain=%d')
print('newline literal :', repr(c[i+7:i+11]))
