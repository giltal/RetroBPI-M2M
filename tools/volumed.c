/*
 * volumed -- system input daemon: volume on the pad, and a CLEAN POWER OFF.
 *
 * ---------------------------------------------------------------- volume ----
 * RetroArch's volume hotkeys adjust its own internal audio_volume, an in-memory
 * dB gain discarded when RetroArch exits, so every launch started at full volume
 * again. It cannot be persisted: config_save_on_exit is off deliberately (it
 * rewrote audio_driver to "null"), RetroArch never logs the volume so there is
 * nothing to scrape, and parallel-n64 SIGSEGVs on teardown so an on-exit save
 * would miss N64 anyway. So drive the ALSA mixer instead -- S35alsa already
 * persists it with alsactl store/restore.
 *
 * ----------------------------------------------------------------- power ----
 * NOTHING was handling KEY_POWER from axp20x-pek. Pressing the button did
 * nothing, so the only way to switch the console off was to hold it until the
 * PMIC cut the rail -- an abrupt power loss with no filesystem flush.
 *
 * That is not cosmetic. It cost the Bluetooth pairing TWICE: the bond directory
 * under /var/lib/bluetooth was written, then lost, and the boot afterwards
 * logged "EXT4-fs: recovery required". Anything ext4 has not committed yet dies
 * with the power -- and that includes .srm game saves written seconds earlier.
 * Reboots issued over SSH were always clean, which is exactly why this took two
 * occurrences to spot: the failure only happens the way a console is actually
 * used.
 *
 * So: KEY_POWER now syncs and powers down properly.
 *
 * Reading these devices alongside RetroArch is safe -- its udev input driver
 * never calls EVIOCGRAB, so every reader gets its own copy of each event.
 *
 * Pad button codes were derived from the device key bitmap and verified against
 * RetroArch's autoconfig (all twelve indices matched; this clone reports BTN_C
 * for A because BTN_EAST is absent). PS is BTN_MODE, volume is the d-pad.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <dirent.h>
#include <time.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <linux/input.h>

#define PAD_NAME    "Sony PLAYSTATION(R)3 Controller"
#define PEK_NAME    "axp20x-pek"
#define MIXER       "Headphone"
#define VOL_MIN     10
#define VOL_MAX     100
#define VOL_STEP    5
#define STORE_DELAY 5

static int open_by_name(const char *want)
{
	DIR *d = opendir("/dev/input");
	struct dirent *e;
	char path[64], name[256];
	int fd;

	if (!d)
		return -1;
	while ((e = readdir(d))) {
		if (strncmp(e->d_name, "event", 5))
			continue;
		snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
		if ((fd = open(path, O_RDONLY | O_NONBLOCK)) < 0)
			continue;
		name[0] = 0;
		/* exact match: "...Controller" must not also catch
		 * "...Controller Motion Sensors" */
		if (ioctl(fd, EVIOCGNAME(sizeof name), name) >= 0 && !strcmp(name, want)) {
			closedir(d);
			return fd;
		}
		close(fd);
	}
	closedir(d);
	return -1;
}

static int cur_volume(void)
{
	FILE *p = popen("amixer sget " MIXER " 2>/dev/null | "
	                "grep -o '\[[0-9]*%\]' | head -1 | tr -dc '0-9'", "r");
	int v = -1;
	if (p) {
		if (fscanf(p, "%d", &v) != 1)
			v = -1;
		pclose(p);
	}
	return v;
}

static void adjust_volume(int up)
{
	char cmd[128];
	int v = cur_volume(), t;

	if (v < 0)
		return;
	t = up ? v + VOL_STEP : v - VOL_STEP;
	if (t > VOL_MAX) t = VOL_MAX;
	/* Clamp instead of walking to 0%: a console that has silently muted
	 * itself looks broken, not quiet. */
	if (t < VOL_MIN) t = VOL_MIN;
	if (t == v)
		return;
	snprintf(cmd, sizeof cmd, "amixer -q sset " MIXER " %d%% >/dev/null 2>&1", t);
	if (system(cmd) == -1)
		return;
}

static void power_off(void)
{
	/* Flush before asking init to stop anything. The whole point of handling
	 * this key is that the alternative -- holding the button until the PMIC
	 * cuts the rail -- loses unwritten data. */
	sync();
	sleep(1);
	sync();
	if (system("poweroff") == -1)
		if (system("halt") == -1)
			return;
}

int main(void)
{
	int pad = -1, pek = -1, mode_held = 0;
	time_t dirty_at = 0, pad_seen_at = 0;

	for (;;) {
		struct pollfd pfd[2];
		struct input_event ev;
		int n = 0, pad_i = -1, pek_i = -1;

		if (pad < 0) {
			pad = open_by_name(PAD_NAME);
			if (pad >= 0)
				pad_seen_at = time(NULL);	/* fresh bond -> flush it */
		}
		if (pek < 0)
			pek = open_by_name(PEK_NAME);

		if (pad >= 0) { pfd[n].fd = pad; pfd[n].events = POLLIN; pad_i = n++; }
		if (pek >= 0) { pfd[n].fd = pek; pfd[n].events = POLLIN; pek_i = n++; }

		if (n == 0) {			/* nothing to watch yet */
			sleep(2);
			continue;
		}
		poll(pfd, n, 1000);

		if (pad_i >= 0 && (pfd[pad_i].revents & (POLLERR | POLLHUP))) {
			close(pad); pad = -1; mode_held = 0;
		} else if (pad_i >= 0 && (pfd[pad_i].revents & POLLIN)) {
			while (read(pad, &ev, sizeof ev) == (ssize_t)sizeof ev) {
				if (ev.type != EV_KEY)
					continue;
				if (ev.code == BTN_MODE)
					mode_held = (ev.value != 0);
				else if (mode_held && ev.value == 1 &&
				         (ev.code == BTN_DPAD_UP || ev.code == BTN_DPAD_DOWN)) {
					adjust_volume(ev.code == BTN_DPAD_UP);
					dirty_at = time(NULL);
				}
			}
			if (errno != EAGAIN) { close(pad); pad = -1; mode_held = 0; }
		}

		if (pek_i >= 0 && (pfd[pek_i].revents & POLLIN)) {
			while (read(pek, &ev, sizeof ev) == (ssize_t)sizeof ev)
				if (ev.type == EV_KEY && ev.code == KEY_POWER && ev.value == 1)
					power_off();
			if (errno != EAGAIN) { close(pek); pek = -1; }
		}

		/* Persist the mixer once the user stops adjusting, not per step --
		 * alsactl store writes to the SD card. */
		if (dirty_at && time(NULL) - dirty_at >= STORE_DELAY) {
			if (system("alsactl store >/dev/null 2>&1") == -1)
				;
			dirty_at = 0;
		}
		/* A newly paired pad means bluetoothd just wrote a link key. Commit it,
		 * rather than leaving it in page cache where a power cut eats it --
		 * which is how this pairing was lost twice. */
		if (pad_seen_at && time(NULL) - pad_seen_at >= 3) {
			sync();
			pad_seen_at = 0;
		}
	}
	return 0;
}
