/* Host-side unit test of the exact system_from_path logic, so the fix is proven
 * before it goes near the board. Mirrors the launcher's table and helper. */
#include <stdio.h>
#include <string.h>
#include <strings.h>
#define ROMS_PATH "/opt/roms"
#define MAX_NAME 256
static const char *dirs[] = { "nes","snes","gb","gbc","gba","genesis","mastersystem",
  "gamegear","atari2600","atari7800","atari800","pce","pcesupergrafx","zxspectrum",
  "psx","doom","neogeo","cps1","cps2","cps3","arcade","mame","n64", NULL };
static int system_from_path(const char *path)
{
    const char *p = path; const char *slash; char dir[MAX_NAME];
    size_t n, bl = strlen(ROMS_PATH);
    if (strncmp(path, ROMS_PATH, bl) == 0) { p = path + bl; while (*p == '/') p++; }
    else return -1;
    slash = strchr(p, '/'); if (!slash) return -1;
    n = (size_t)(slash - p); if (n >= sizeof dir) n = sizeof dir - 1;
    memcpy(dir, p, n); dir[n] = '\0';
    for (int s = 0; dirs[s]; s++) if (strcasecmp(dir, dirs[s]) == 0) return s;
    return -1;
}
int main(void)
{
    struct { const char *path; const char *want; } t[] = {
        { "/opt/roms/N64/Mario Kart 64 (USA).zip", "n64"       },  /* the bug */
        { "/opt/roms/n64/Zelda.z64",               "n64"       },
        { "/opt/roms/mame/pacman.zip",             "mame"      },
        { "/opt/roms/atari2600/Asteroids.a26",     "atari2600" },
        { "/opt/roms/atari800/Donkey Kong.atr",    "atari800"  },
        { "/opt/roms/GBA/Pokemon.gba",             "gba"       },  /* future caps */
        { "/opt/roms/gb/Tetris.gb",                "gb"        },
        { "/opt/roms/nosuch/x.rom",                NULL        },
        { "/opt/roms/loose.zip",                   NULL        },  /* no subdir */
        { "/somewhere/else/n64/x.z64",             NULL        },  /* outside tree */
    };
    int fail = 0;
    for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) {
        int r = system_from_path(t[i].path);
        const char *got = (r >= 0) ? dirs[r] : NULL;
        int ok = (!got && !t[i].want) || (got && t[i].want && !strcmp(got, t[i].want));
        printf("  %-42s -> %-10s %s\n", t[i].path, got ? got : "(none)", ok ? "ok" : "FAIL");
        if (!ok) fail = 1;
    }
    printf(fail ? "FAILURES\n" : "all cases pass\n");
    return fail;
}
