import io, glob, os, sys
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
orig = p + '.orig'
if not os.path.exists(orig):
    io.open(orig,'w',encoding='utf-8',newline='').write(
        io.open(p,encoding='utf-8',newline='').read())
s = io.open(orig, encoding='utf-8', newline='').read()

helper = (
'\n/* RetroBPI: objective glitch detector.\n'
' * The ALSA buffer was measured healthy (95-96 ms margin, no underruns) while\n'
' * breaks were still audible, so the defect is in the sample CONTENT, not in\n'
' * delivery. A click/pop is a large sample-to-sample discontinuity. Count them,\n'
' * including across batch boundaries, so glitches can be compared between\n'
' * configurations without needing anyone to listen.\n'
' */\n'
'static void glitch_scan(const int16_t *buf, size_t frames)\n'
'{\n'
'    static int16_t prevL = 0, prevR = 0;\n'
'    static unsigned long nglitch = 0, nframes = 0, logged = 0;\n'
'    static int maxjump = 0;\n'
'    static unsigned last_report = 0;\n'
'    size_t i;\n'
'    FILE *f;\n'
'    for (i = 0; i < frames; i++) {\n'
'        int l = buf[i*2], r = buf[i*2+1];\n'
'        int dl = l - prevL, dr = r - prevR;\n'
'        if (dl < 0) dl = -dl;\n'
'        if (dr < 0) dr = -dr;\n'
'        if (dl > maxjump) maxjump = dl;\n'
'        if (dr > maxjump) maxjump = dr;\n'
'        if (dl > 12000 || dr > 12000) {\n'
'            nglitch++;\n'
'            if (logged < 200) {\n'
'                logged++;\n'
'                f = fopen("/tmp/glitch.log", "a");\n'
'                if (f) { fprintf(f, "GLITCH at_frame=%lu dl=%d dr=%d' + NL + '",\n'
'                                 nframes + i, dl, dr); fclose(f); }\n'
'            }\n'
'        }\n'
'        prevL = l; prevR = r;\n'
'    }\n'
'    nframes += frames;\n'
'    if (nframes - last_report >= 44100) {\n'
'        last_report = nframes;\n'
'        f = fopen("/tmp/glitch.log", "a");\n'
'        if (f) { fprintf(f, "SEC frames=%lu glitches=%lu maxjump=%d' + NL + '",\n'
'                         nframes, nglitch, maxjump); fclose(f); }\n'
'        maxjump = 0;\n'
'    }\n'
'}\n'
)

anchor = 'static void aiLenChanged(void* user_data, const void* buffer, size_t size)'
assert s.count(anchor) == 1
s = s.replace(anchor, helper + '\n' + anchor)

old = '''   out                    = audio_out_buffer_s16;
'''
assert s.count(old) == 1
s = s.replace(old, '''   out                    = audio_out_buffer_s16;

   glitch_scan(audio_out_buffer_s16, data.output_frames);
''')
io.open(p,'w',encoding='utf-8',newline='').write(s)
chk = io.open(p, encoding='utf-8', newline='').read()
i = chk.find('dr=%d')
print('installed. newline literal:', repr(chk[i+5:i+9]))
print('glitch_scan call sites:', chk.count('glitch_scan('))
