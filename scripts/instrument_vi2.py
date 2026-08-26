import io, glob, os, sys
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))
if not d: sys.exit('no build dir')
p = d[0] + 'mupen64plus-video-angrylion/n64video/vi.c'
orig = p + '.orig'
if not os.path.exists(orig): sys.exit('no .orig backup - refusing')
s = io.open(orig, encoding='utf-8', newline='').read()   # always start from pristine

helper = (
 '#include <stdio.h>' + NL.replace(NL,'\n') +
 'static void al_dbg(const char *msg, int v){\n'
 '    static int n = 0;\n'
 '    FILE *f;\n'
 '    if (n >= 40) return;\n'
 '    n++;\n'
 '    f = fopen("/tmp/al_dbg.txt", "a");\n'
 '    if (!f) return;\n'
 '    fprintf(f, "AL_DBG %s %d' + NL + '", msg, v);\n'
 '    fclose(f);\n'
 '}\n'
)
s = helper + s

edits = [
 ('    if (!frame_buffer) {\n        vdac_sync(true);',
  '    if (!frame_buffer) {\n        al_dbg("no_framebuffer", 0);\n        vdac_sync(true);'),
 ('    if (isblank && prevwasblank) {\n        return false;',
  '    if (isblank && prevwasblank) {\n        al_dbg("blank_full", 0);\n        return false;'),
 ('    if (!validh) {\n        return false;',
  '    if (!validh) {\n        al_dbg("validh_fail", hres);\n        return false;'),
 ('    vdac_sync(!valid);',
  '    al_dbg("vdac_sync_valid", (int)valid);\n    vdac_sync(!valid);'),
 ('void vdac_write(struct frame_buffer* fb)',
  'void vdac_write(struct frame_buffer* fb)'),   # no-op marker
]
for old, new in edits:
    c = s.count(old)
    if c == 1 and old != new:
        s = s.replace(old, new); print('%-42s OK' % old.strip().split('\n')[0][:42])
    elif old != new:
        print('%-42s SKIP count=%d' % (old.strip().split('\n')[0][:42], c))
io.open(p, 'w', encoding='utf-8', newline='').write(s)
# verify the C newline escape really is two chars
chk = io.open(p, encoding='utf-8', newline='').read()
i = chk.find('AL_DBG %s %d')
print('escape bytes after format:', repr(chk[i+12:i+16]))
