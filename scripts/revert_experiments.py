import io, glob, os
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
for rel in ('libretro/libretro.c',
            'mupen64plus-core/src/plugin/plugin.c',
            'mupen64plus-core/src/vi/vi_controller.c',
            'mupen64plus-video-angrylion/n64video/vi.c'):
    p = d + rel
    if os.path.exists(p + '.orig'):
        io.open(p,'w',encoding='utf-8',newline='').write(
            io.open(p+'.orig',encoding='utf-8',newline='').read())
        os.remove(p + '.orig')
        print('restored', rel)
    else:
        s = io.open(p, encoding='utf-8', newline='').read()
        marks = [m for m in ('RetroBPI', 'al_dbg', 'al_dump', 'vw_log', 'GfxCheckInterrupts') if m in s]
        print('%-46s no .orig; leftover markers: %s' % (rel, marks or 'none'))
