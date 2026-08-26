import io, glob, os
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
orig = p + '.orig'
if not os.path.exists(orig):
    io.open(orig,'w',encoding='utf-8',newline='').write(
        io.open(p,encoding='utf-8',newline='').read())
s = io.open(orig, encoding='utf-8', newline='').read()

helper = (
'\n/* RetroBPI: audio anomaly detector.\n'
' * Established by measurement: sample count and rate are exactly correct, the\n'
' * ALSA margin never dips below 92 ms, and there are no sample-to-sample\n'
' * discontinuities. So the defect is neither delivery nor a click.\n'
' *\n'
' * Remaining suspect: CLIPPING. The core resamples with sinc, which overshoots\n'
' * on intersample peaks; if the source is mastered near full scale the output\n'
' * exceeds +-32767 and is clamped. That needs no excess gain (both digital\n'
' * stages measured at unity), produces flat-topped waveforms rather than jumps,\n'
' * and gets worse the louder the passage -- matching "only deep in gameplay".\n'
' * A jump detector is blind to it by construction.\n'
' *\n'
' * Also counts near-silence runs, to catch a brief gap that would not register\n'
' * as a jump if it happens during a quiet passage.\n'
' */\n'
'static void glitch_scan(const int16_t *buf, size_t frames)\n'
'{\n'
'    static int16_t prevL = 0, prevR = 0;\n'
'    static unsigned long nframes = 0, njump = 0, nclip = 0, nsil = 0;\n'
'    static unsigned long last_report = 0, silrun = 0;\n'
'    static int maxjump = 0, peak = 0;\n'
'    static unsigned long clip_sec = 0, jump_sec = 0;\n'
'    size_t i;\n'
'    FILE *f;\n'
'    for (i = 0; i < frames; i++) {\n'
'        int l = buf[i*2], r = buf[i*2+1];\n'
'        int al = l < 0 ? -l : l, ar = r < 0 ? -r : r;\n'
'        int dl = l - prevL, dr = r - prevR;\n'
'        if (dl < 0) dl = -dl;\n'
'        if (dr < 0) dr = -dr;\n'
'        if (dl > maxjump) maxjump = dl;\n'
'        if (dr > maxjump) maxjump = dr;\n'
'        if (al > peak) peak = al;\n'
'        if (ar > peak) peak = ar;\n'
'        if (al >= 32700 || ar >= 32700) { nclip++; clip_sec++; }\n'
'        if (dl > 12000 || dr > 12000) { njump++; jump_sec++; }\n'
'        if (al < 64 && ar < 64) { silrun++; }\n'
'        else { if (silrun > 441) nsil++; silrun = 0; }\n'
'        prevL = l; prevR = r;\n'
'    }\n'
'    nframes += frames;\n'
'    if (nframes - last_report >= 44100) {\n'
'        last_report = nframes;\n'
'        f = fopen("/tmp/glitch.log", "a");\n'
'        if (f) {\n'
'            fprintf(f, "SEC t=%lu peak=%d clip=%lu jump=%lu maxjump=%d sil=%lu' + NL + '",\n'
'                    nframes/44100, peak, clip_sec, jump_sec, maxjump, nsil);\n'
'            fclose(f);\n'
'        }\n'
'        maxjump = 0; peak = 0; clip_sec = 0; jump_sec = 0;\n'
'    }\n'
'}\n'
)
anchor = 'static void aiLenChanged(void* user_data, const void* buffer, size_t size)'
assert s.count(anchor) == 1
s = s.replace(anchor, helper + '\n' + anchor)
old = '   out                    = audio_out_buffer_s16;\n'
assert s.count(old) == 1
s = s.replace(old, old + '\n   glitch_scan(audio_out_buffer_s16, data.output_frames);\n')
io.open(p,'w',encoding='utf-8',newline='').write(s)
c = io.open(p, encoding='utf-8', newline='').read()
i = c.find('sil=%lu')
print('installed; newline literal:', repr(c[i+7:i+11]))
print('call sites:', c.count('glitch_scan('))
