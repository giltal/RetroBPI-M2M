#!/bin/sh
#
# post-build: remove files that no longer belong in the image.
#
# Buildroot's target/ directory is INCREMENTAL. Disabling a package or renaming
# an overlay file does not delete what a previous build already installed, so
# the stale copy silently survives into the image. This project has been bitten
# by that three times now:
#
#   - etc/default/udevd persisted after the overlay stopped shipping it
#   - BR2_SYSTEM_DHCP appeared to do nothing because an old interfaces file won
#   - S99launcher would have shipped alongside S12launcher after the rename,
#     starting the launcher twice -- the second instance failing with
#     "DRM: setCrtc failed: Permission denied" because the first holds master
#   - the N64 audio_latency=256 override survived being deleted from the overlay,
#     so an image built "without" it still carried 128 ms of needless audio lag
#
# A full `make clean` would also fix it, but that means rebuilding RetroArch and
# every core. Removing the specific known-stale paths is cheap and explicit.
#
# TARGET_DIR is passed as $1 by Buildroot.

set -e
TARGET_DIR="$1"

# Renamed 2026-08-21: launcher moved from S99 to S12 (boot ordering).
rm -f "$TARGET_DIR/etc/init.d/S99launcher"

# Removed 2026-08-21: ADB never worked with this 2013-vintage android-tools,
# and composing its USB gadget cost 1.18 s of every boot.
rm -f "$TARGET_DIR/etc/init.d/S50adbd"
rm -f "$TARGET_DIR/usr/bin/adbd"
rm -f "$TARGET_DIR/usr/bin/adb"

# Removed 2026-08-24: the N64-only audio_latency override. alsathread reaches
# zero xruns at the normal 128 ms latency, so this override only added delay.
rm -f "$TARGET_DIR/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg"

# Guard: exactly one launcher init script must remain.
n=$(ls "$TARGET_DIR"/etc/init.d/S??launcher 2>/dev/null | wc -l)
if [ "$n" -ne 1 ]; then
	echo "post-build.sh: ERROR: expected 1 launcher init script, found $n" >&2
	ls "$TARGET_DIR"/etc/init.d/ >&2
	exit 1
fi
# Guard: the threaded ALSA driver must be what actually ships. N64 audio depends
# on it (inline alsa writes starve the card when the emulator misses a deadline),
# and it is easy to lose to a stale target/ copy of retroarch.cfg.
racfg="$TARGET_DIR/root/.config/retroarch/retroarch.cfg"
if ! grep -q '^audio_driver = "alsathread"' "$racfg"; then
	echo "post-build.sh: ERROR: audio_driver is not alsathread in the shipped config" >&2
	grep '^audio_driver' "$racfg" >&2 || echo "  (no audio_driver line at all)" >&2
	exit 1
fi
stale="$TARGET_DIR/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg"
if [ -e "$stale" ]; then
	echo "post-build.sh: ERROR: N64 latency override still present in target/" >&2
	exit 1
fi

# Guard: no diagnostic instrumentation may reach an image.
#
# Cores get temporarily patched with probes during investigations (audio clip
# detection, emulation-speed timing, analog-stick histograms). Restoring the
# SOURCE to pristine does NOT rebuild the binary, and target/ is incremental --
# so an instrumented .so survives into the image while the source looks clean.
# That happened: an image was built and copied to firmware/ containing an
# analog-probe build, and was only caught by a strings check in a push script.
# Verifying the source is not the same as verifying the artifact.
for so in "$TARGET_DIR"/usr/lib/libretro/*.so; do
	[ -e "$so" ] || continue
	if strings "$so" 2>/dev/null | grep -qE 'astick\.log|glitch\.log|ra_audio\.log|speed_permille|RETROBPI_AUDIO_PROBE'; then
		echo "post-build.sh: ERROR: $(basename $so) contains diagnostic instrumentation" >&2
		echo "  rebuild it from pristine source before building an image" >&2
		exit 1
	fi
done

echo "post-build.sh: image cleaned; launcher script: $(ls "$TARGET_DIR"/etc/init.d/S??launcher | sed 's|.*/||')"
