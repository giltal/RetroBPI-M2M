import io, glob, os
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
if os.path.exists(p + '.orig'):
    io.open(p,'w',encoding='utf-8',newline='').write(
        io.open(p+'.orig',encoding='utf-8',newline='').read())
    os.remove(p + '.orig')
    print('audio_backend_libretro.c restored to pristine')
s = io.open(p, encoding='utf-8', newline='').read()
print('glitch_scan refs remaining:', s.count('glitch_scan'))
