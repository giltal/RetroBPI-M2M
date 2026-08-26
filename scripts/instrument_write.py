import io, glob, os, sys
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))
p = d[0] + 'mupen64plus-core/src/vi/vi_controller.c'
orig = p + '.orig'
if not os.path.exists(orig):
    io.open(orig,'w',encoding='utf-8',newline='').write(
        io.open(p,encoding='utf-8',newline='').read())
s = io.open(orig, encoding='utf-8', newline='').read()

helper = (
 '#include <stdio.h>\n'
 'static void vw_log(unsigned reg, unsigned word, unsigned mask, unsigned cur){\n'
 '    static int n = 0;\n'
 '    static int tot = 0;\n'
 '    FILE *f;\n'
 '    tot++;\n'
 '    if (reg != 1 && reg != 9) return;   /* ORIGIN=1, H_START=9 */\n'
 '    if (n >= 30) return;\n'
 '    n++;\n'
 '    f = fopen("/tmp/vi_writes.txt", "a");\n'
 '    if (!f) return;\n'
 '    fprintf(f, "WRITE reg=%u word=%08x mask=%08x was=%08x totalvi=%d' + NL + '",\n'
 '            reg, word, mask, cur, tot);\n'
 '    fclose(f);\n'
 '}\n'
)
s = helper + s

anchor = '    struct vi_controller* vi = (struct vi_controller*)opaque;\n    uint32_t reg             = VI_REG(address);\n'
if s.count(anchor) != 1: sys.exit('anchor count %d' % s.count(anchor))
s = s.replace(anchor, anchor + '\n    vw_log(reg, word, mask, vi->regs[reg]);\n')
io.open(p, 'w', encoding='utf-8', newline='').write(s)
chk = io.open(p, encoding='utf-8', newline='').read()
i = chk.find('totalvi=%d')
print('installed. newline literal:', repr(chk[i+10:i+14]))
