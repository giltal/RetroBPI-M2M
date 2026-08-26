import io, glob, os
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-atari800-*'))[0]

# --- platform.c: accept R as well as L3 ---
p = d + '/libretro/platform.c'
if not os.path.exists(p + '.orig'):
    io.open(p+'.orig','w',encoding='utf-8',newline='').write(
        io.open(p,encoding='utf-8',newline='').read())
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

old = """			if (mbt[i][RETRO_DEVICE_ID_JOYPAD_L3])
				if (!SHOWKEYDELAY)
				{
					SHOWKEY = -SHOWKEY;
					SHOWKEYDELAY = 20;
				}"""
assert s.count(old) == 1, s.count(old)
new = """			/* RetroBPI: accept R as well as L3 for the virtual keyboard.
			 *
			 * L3 alone is unusable on the DualShock 3 this device ships with.
			 * Captured with evtest: clicking the left stick emits BTN_TL2 (312)
			 * and the right stick BTN_TR2 (313) -- the L2/R2 trigger codes.
			 * BTN_THUMBL (317) and BTN_THUMBR (318) are advertised in the
			 * device's KEY bitmask but are never actually emitted, so the core
			 * could never see its own toggle.
			 *
			 * R is free here: the input descriptors bind L (Option) but not R,
			 * and the comment above notes R was deliberately left unbound when
			 * AKEY_UI stopped doing anything. BTN_TR does arrive from this pad.
			 *
			 * L3 is kept so the binding still works on hardware that reports
			 * thumb-stick clicks properly. */
			if (mbt[i][RETRO_DEVICE_ID_JOYPAD_L3] || mbt[i][RETRO_DEVICE_ID_JOYPAD_R])
				if (!SHOWKEYDELAY)
				{
					SHOWKEY = -SHOWKEY;
					SHOWKEYDELAY = 20;
				}"""
s = s.replace(old, new)
io.open(p,'w',encoding='utf-8',newline='').write(s)

# --- libretro-core.c: describe R in the UI ---
q = d + '/libretro/libretro-core.c'
if not os.path.exists(q + '.orig'):
    io.open(q+'.orig','w',encoding='utf-8',newline='').write(
        io.open(q,encoding='utf-8',newline='').read())
t = io.open(q + '.orig', encoding='utf-8', newline='').read()
oldd = '   { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3, "Virtual Keyboard" },\n'
assert t.count(oldd) == 1
newd = ('   { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3, "Virtual Keyboard" },\n'
        '   { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R, "Virtual Keyboard (alt)" },\n')
t = t.replace(oldd, newd)
io.open(q,'w',encoding='utf-8',newline='').write(t)

a = io.open(p, encoding='utf-8', newline='').read()
b = io.open(q, encoding='utf-8', newline='').read()
print('platform.c  : R accepted   =', 'JOYPAD_L3] || mbt[i][RETRO_DEVICE_ID_JOYPAD_R]' in a)
print('platform.c  : braces ok    =', a.count('{') == a.count('}'))
print('core.c      : descriptor   =', 'Virtual Keyboard (alt)' in b)
print('core.c      : braces ok    =', b.count('{') == b.count('}'))
