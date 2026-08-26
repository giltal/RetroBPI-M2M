"""Produce the SHIPPING version of the core audio fixes: the three real changes,
with all diagnostic instrumentation removed."""
import io, glob, os
d = glob.glob(os.path.expanduser('~/bpi/output/build/libretro-paralleln64-*/'))[0]

# ---- audio backend ----
p = d + 'mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c'
s = io.open(p + '.orig', encoding='utf-8', newline='').read()

hdr = """
/* RetroBPI: N64 audio fixes. Three changes, each measured on hardware.
 *
 * (1) HEADROOM. The output was clipping: 436 samples pinned at full scale in
 *     one session, peak 32768 (the clamp limit), heard as "a bit dirty".
 *     The clamp is in convert_float_to_s16 AFTER sinc resampling, and sinc
 *     overshoots on intersample peaks, so material mastered near 0 dBFS exceeds
 *     full scale once resampled even with every gain stage at unity. Measured
 *     overshoot was 1060 permille, i.e. 6% over. Attenuating on the way IN
 *     fixes it; lowering the ALSA volume could not, because the damage is done
 *     here. 0.8 = -1.94 dB, comfortably clear of the measured 1060.
 *
 * (2) NATIVE 48 kHz. The core resampled to a hardcoded 44100 while the codec
 *     runs at 48000, so every sample went through two conversions:
 *     32000 -> 44100 here and 44100 -> 48000 in the frontend. Targeting 48000
 *     makes it a single conversion at exactly 1.5 for a 32 kHz game and lets
 *     the frontend pass audio through untouched. Verified by capturing the
 *     stream: energy above 16 kHz sits at -116 dB, HF/LF ratio 0.0001, i.e.
 *     no audible aliasing.
 *
 * (3) RESAMPLER QUALITY. Was RESAMPLER_QUALITY_DONTCARE, which asks for
 *     whatever is cheapest. Raised to HIGHER.
 *
 * NOTE: none of these was the main cause of the reported dirt. That was the
 * emulator running at 87% of real time, with the frontend's dynamic rate
 * control stretching audio to hide it -- fixed by rendering at the N64's
 * native 320x240 instead of 640x480 (see the .opt file). These three remain
 * worth having on their own merits.
 */
#define AUDIO_HEADROOM_GAIN 0.8f
#define AUDIO_TARGET_RATE   48000.0

"""
anchor = 'static void aiLenChanged(void* user_data, const void* buffer, size_t size)'
assert s.count(anchor) == 1
s = s.replace(anchor, hdr.lstrip('\n') + anchor)

old_q = 'retro_resampler_realloc(&resampler_audio_data, &resampler, "sinc", RESAMPLER_QUALITY_DONTCARE, 1.0);'
assert s.count(old_q) == 1
s = s.replace(old_q, 'retro_resampler_realloc(&resampler_audio_data, &resampler, "sinc",\n         RESAMPLER_QUALITY_HIGHER, 1.0);')

old_r = '   ratio             = 44100.0 / GameFreq;'
assert s.count(old_r) == 1
s = s.replace(old_r, '   ratio             = AUDIO_TARGET_RATE / GameFreq;')

old_m = '   max_frames        = (GameFreq > 44100) ? MAX_AUDIO_FRAMES : (size_t)(MAX_AUDIO_FRAMES / ratio - 1);'
assert s.count(old_m) == 1
s = s.replace(old_m, '   max_frames        = (GameFreq > AUDIO_TARGET_RATE)\n      ? MAX_AUDIO_FRAMES : (size_t)(MAX_AUDIO_FRAMES / ratio - 1);')

old_g = 'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2, 1.0f);'
assert s.count(old_g) == 1
s = s.replace(old_g, 'convert_s16_to_float(audio_in_buffer_float, raw_data, frames * 2,\n         AUDIO_HEADROOM_GAIN);')

io.open(p, 'w', encoding='utf-8', newline='').write(s)

# ---- libretro.c: declared sample rate ----
q = d + 'libretro/libretro.c'
t = io.open(q + '.orig', encoding='utf-8', newline='').read()
old_sr = '   info->timing.sample_rate = 44100.0;'
assert t.count(old_sr) == 1
t = t.replace(old_sr,
  '   /* RetroBPI: 48000 to match the codec exactly, so the frontend performs no\n'
  '    * rate conversion at all. The core now resamples straight to this rate. */\n'
  '   info->timing.sample_rate = 48000.0;')
io.open(q, 'w', encoding='utf-8', newline='').write(t)

c = io.open(p, encoding='utf-8', newline='').read()
print('instrumentation removed :', 'audio_probe' not in c and 'glitch.log' not in c)
print('headroom gain           :', 'AUDIO_HEADROOM_GAIN);' in c)
print('48k target              :', 'AUDIO_TARGET_RATE / GameFreq' in c)
print('quality HIGHER          :', 'RESAMPLER_QUALITY_HIGHER' in c)
print('declared 48000          :', 'sample_rate = 48000.0;' in t)
print('braces balanced         :', c.count('{') == c.count('}'))
