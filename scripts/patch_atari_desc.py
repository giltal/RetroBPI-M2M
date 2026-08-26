import io, glob, os
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-atari800-*'))[0]
q = d + '/libretro/libretro-core.c'
t = io.open(q + '.orig', encoding='utf-8', newline='').read()

# this file uses CRLF; match whatever terminator the line actually has
key = '{ 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3, "Virtual Keyboard" },'
assert t.count(key) == 1, t.count(key)
i = t.index(key) + len(key)
eol = '\r\n' if t[i:i+2] == '\r\n' else '\n'
indent = '   '
add = eol + indent + '{ 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R, "Virtual Keyboard (alt)" },'
t = t[:i] + add + t[i:]
io.open(q, 'w', encoding='utf-8', newline='').write(t)

c = io.open(q, encoding='utf-8', newline='').read()
print('line ending detected :', repr(eol))
print('descriptor added     :', 'Virtual Keyboard (alt)' in c)
print('braces balanced      :', c.count('{') == c.count('}'))
