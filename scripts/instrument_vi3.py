import io, glob, os, sys
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))
p = d[0] + 'mupen64plus-video-angrylion/n64video/vi.c'
orig = p + '.orig'
s = io.open(orig, encoding='utf-8', newline='').read()      # pristine

helper = (
 '#include <stdio.h>\n'
 'static void al_dbg(const char *msg, unsigned a, unsigned b, unsigned c, unsigned e){\n'
 '    static int n = 0;\n'
 '    FILE *f;\n'
 '    if (n >= 20000) return;\n'
 '    n++;\n'
 '    f = fopen("/tmp/al_dbg.txt", "a");\n'
 '    if (!f) return;\n'
 '    fprintf(f, "AL_DBG %s origin=%08x status=%08x width=%08x vsync=%08x' + NL + '",\n'
 '            msg, a, b, c, e);\n'
 '    fclose(f);\n'
 '}\n'
)
s = helper + s

REGS = ('*vi_reg_ptr[VI_ORIGIN], *vi_reg_ptr[VI_STATUS], '
        '*vi_reg_ptr[VI_WIDTH], *vi_reg_ptr[VI_V_SYNC]')

edits = [
 ('    if (!frame_buffer) {\n        vdac_sync(true);',
  '    if (!frame_buffer) {\n        al_dbg("no_framebuffer", ' + REGS + ');\n        vdac_sync(true);'),
 ('    vdac_sync(!valid);',
  '    al_dbg(valid ? "sync_VALID" : "sync_invalid", ' + REGS + ');\n    vdac_sync(!valid);'),
 ('    if (!validh) {\n        return false;',
  '    if (!validh) {\n        al_dbg("validh_fail", hres, h_start, 0, 0);\n        return false;'),
 ('    if (isblank && prevwasblank) {\n        return false;',
  '    if (isblank && prevwasblank) {\n        al_dbg("blank_full", 0, 0, 0, 0);\n        return false;'),
]
for old, new in edits:
    c = s.count(old)
    if c == 1: s = s.replace(old, new); print('%-40s OK' % old.strip().split('\n')[0][:40])
    else:      print('%-40s SKIP count=%d' % (old.strip().split('\n')[0][:40], c))
io.open(p, 'w', encoding='utf-8', newline='').write(s)
chk = io.open(p, encoding='utf-8', newline='').read()
i = chk.find('vsync=%08x')
print('escape after fmt:', repr(chk[i+10:i+14]), ' call sites:', chk.count('al_dbg("') + chk.count('al_dbg(valid'))
