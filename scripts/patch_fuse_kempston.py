import io, glob, os
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-fuse-*'))[0]
p = d + '/src/libretro.c'
if not os.path.exists(p + '.orig'):
    io.open(p+'.orig','w',encoding='utf-8',newline='').write(
        io.open(p,encoding='utf-8',newline='').read())
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

# 1. default port 0 to Kempston rather than Cursor
old1 = 'retro_set_controller_port_device( 0, RETRO_DEVICE_CURSOR_JOYSTICK );'
assert s.count(old1) == 1, s.count(old1)
new1 = ('/* RetroBPI: Kempston, not Cursor. Kempston is what Spectrum games\n'
        '    * overwhelmingly expect; Cursor maps the stick to keyboard keys. */\n'
        '   retro_set_controller_port_device( 0, RETRO_DEVICE_KEMPSTON_JOYSTICK );')
s = s.replace(old1, new1)

# 2. treat plain RETRO_DEVICE_JOYPAD as Kempston.
#    Anchor by index rather than matching the log_cb line, which contains a
#    backslash escape that does not survive being written through a heredoc.
fn = 'void retro_set_controller_port_device(unsigned port, unsigned device)'
i = s.index(fn)
sw = s.index('   switch (device)', i)          # first switch after the function opens
assert sw > i

ins = (
'   /* RetroBPI: treat plain RETRO_DEVICE_JOYPAD as Kempston.\n'
'    *\n'
'    * RetroArch calls this with RETRO_DEVICE_JOYPAD (value 1) after core init,\n'
'    * overriding whatever default was set at startup. Plain JOYPAD matches none\n'
'    * of the Spectrum joystick cases below, so it falls through to default:,\n'
'    * which records input_devices[port] but never sets joystick_1_output -- the\n'
'    * joystick is then silently dead no matter what the user presses.\n'
'    *\n'
'    * Mapping it to Kempston keeps joystick input alive whatever the frontend\n'
'    * sends, and Kempston is the right default for Spectrum software.\n'
'    *\n'
'    * Ported from the LyraZeroW project, which hit and solved this on the same\n'
'    * fuse commit (69a44421). */\n'
'   if (device == RETRO_DEVICE_JOYPAD)\n'
'      device = RETRO_DEVICE_KEMPSTON_JOYSTICK;\n'
'\n'
)
s = s[:sw] + ins + s[sw:]

io.open(p,'w',encoding='utf-8',newline='').write(s)
c = io.open(p, encoding='utf-8', newline='').read()
print('default is Kempston  :', 'port_device( 0, RETRO_DEVICE_KEMPSTON_JOYSTICK );' in c)
print('JOYPAD remap present :', 'if (device == RETRO_DEVICE_JOYPAD)' in c)
print('braces balanced      :', c.count('{') == c.count('}'))
