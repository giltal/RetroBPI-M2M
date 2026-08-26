# RetroBPI launcher — cross-compilation for Allwinner A33 (Cortex-A7 + NEON)
#
# Standalone build against the Buildroot toolchain:
#   make SYSROOT=$HOME/bpi/output/host/arm-buildroot-linux-gnueabihf/sysroot \
#        CROSS_COMPILE=$HOME/bpi/output/host/bin/arm-buildroot-linux-gnueabihf-
#
# Panel geometry (see launcher.c):
#   make PANEL_W=1024 PANEL_H=600     # EK79007 7" — bring-up
#   make                              # 800x480 default — Waveshare 5" (B)
#
# When built as a Buildroot package this inherits TARGET_CC / TARGET_CFLAGS.

CROSS_COMPILE ?=
SYSROOT       ?=
PANEL_W       ?= 800
PANEL_H       ?= 480
# Degrees to rotate the output so it appears upright, set by how the panel is
# physically mounted. 0 or 180. See rotation = <180> in the board DTS.
PANEL_ROTATION ?= 0

CC    = $(CROSS_COMPILE)gcc
STRIP = $(CROSS_COMPILE)strip

TARGET = retrobpi_launcher
OBJS   = launcher.o gfx_accel.o

CFLAGS  = -Wall -Wextra -O2 -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard
CFLAGS += -DSCREEN_WIDTH=$(PANEL_W) -DSCREEN_HEIGHT=$(PANEL_H)
CFLAGS += -DPANEL_ROTATION=$(PANEL_ROTATION)
ifneq ($(SYSROOT),)
CFLAGS += --sysroot=$(SYSROOT)
CFLAGS += -I$(SYSROOT)/usr/include/SDL2
CFLAGS += -I$(SYSROOT)/usr/include/libdrm
endif

LDFLAGS =
ifneq ($(SYSROOT),)
LDFLAGS += --sysroot=$(SYSROOT)
endif
# No -lrga: the A33 has no RGA2 engine (see gfx_accel.c).
# No -ljpeg/-lz either: the launcher only asks IMG_Init for PNG and never calls
# jpeg or zlib directly. Those were transitive deps that the Lyra's Rockchip
# sysroot happened to expose; here they resolve through SDL2_image's DT_NEEDED.
LDFLAGS += -lSDL2_ttf -lSDL2_image -lSDL2 -ldrm -lfreetype -lpthread -lm

all: $(TARGET)

launcher.o: launcher.c gfx_accel.h
	$(CC) $(CFLAGS) -c -o $@ $<

gfx_accel.o: gfx_accel.c gfx_accel.h
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET): $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAGS)
	$(STRIP) $@

clean:
	rm -f $(TARGET) $(OBJS)

.PHONY: all clean
