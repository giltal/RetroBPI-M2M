import io, glob, os, sys
BS = chr(92); NL = BS + 'n'
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))
p = d[0] + 'mupen64plus-core/src/vi/vi_controller.c'
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

helper = (
 '#include <stdio.h>\n'
 'static void vw_log(unsigned reg, unsigned word, unsigned mask, unsigned cur){\n'
 '    static unsigned tot = 0, n_org = 0, n_hst = 0;\n'
 '    static unsigned last_org = 0xFFFFFFFF, distinct_org = 0;\n'
 '    static unsigned hst_nonzero = 0, org_changes_logged = 0, hst_logged = 0;\n'
 '    static unsigned summaries = 0;\n'
 '    FILE *f;\n'
 '    tot++;\n'
 '    if (reg == 1) {\n'
 '        n_org++;\n'
 '        if (word != last_org) { distinct_org++; last_org = word;\n'
 '            if (org_changes_logged < 12) { org_changes_logged++;\n'
 '                f = fopen("/tmp/vi_writes.txt","a");\n'
 '                if (f){ fprintf(f,"ORIGIN_CHANGE #%u word=%08x at_write=%u' + NL + '",\n'
 '                        distinct_org, word, tot); fclose(f);} } }\n'
 '    }\n'
 '    if (reg == 9) {\n'
 '        n_hst++;\n'
 '        if (word != 0) { hst_nonzero++;\n'
 '            if (hst_logged < 12) { hst_logged++;\n'
 '                f = fopen("/tmp/vi_writes.txt","a");\n'
 '                if (f){ fprintf(f,"H_START_NONZERO word=%08x mask=%08x at_write=%u' + NL + '",\n'
 '                        word, mask, tot); fclose(f);} } }\n'
 '    }\n'
 '    if (tot %% 2000 == 0 && summaries < 30) {\n'
 '        summaries++;\n'
 '        f = fopen("/tmp/vi_writes.txt","a");\n'
 '        if (f){ fprintf(f,"SUMMARY tot=%u origin_writes=%u distinct_origin=%u '
 'hstart_writes=%u hstart_nonzero=%u' + NL + '",\n'
 '                tot, n_org, distinct_org, n_hst, hst_nonzero); fclose(f);}\n'
 '    }\n'
 '}\n'
)
# %% -> % for the literal modulo in C
helper = helper.replace('tot %% 2000', 'tot % 2000')
s = helper + s
anchor = '    struct vi_controller* vi = (struct vi_controller*)opaque;\n    uint32_t reg             = VI_REG(address);\n'
assert s.count(anchor) == 1
s = s.replace(anchor, anchor + '\n    vw_log(reg, word, mask, vi->regs[reg]);\n')
io.open(p, 'w', encoding='utf-8', newline='').write(s)
c = io.open(p, encoding='utf-8', newline='').read()
print('mod op present:', 'tot % 2000' in c, '| newline ok:', repr(c[c.find('at_write=%u')+11:][:4]))
