################################################################################
#
# GPSP
#
################################################################################
# gpSP is the GBA core that matters on this class of hardware: it JIT-compiles
# ARM7TDMI to native ARMv7 via an mmap'd dynarec cache, where mGBA is a pure
# interpreter. The Lyra project measured 3-5x, taking GBA from below 60 fps to
# full speed on the same Cortex-A7 at the same clock.
#
# The version this package originally pinned (d99f3ac) fails to assemble with a
# modern binutils -- "changed section attributes for .jit" -- which is why the
# core was marked broken and disabled. That is fixed upstream; this is the
# commit the Lyra project verified at full speed.
LIBRETRO_GPSP_VERSION = d6decfa351b575e2936afebba26d41ec20e4ddcd
LIBRETRO_GPSP_SITE = $(call github,libretro,gpsp,$(LIBRETRO_GPSP_VERSION))

define LIBRETRO_GPSP_BUILD_CMDS
	CFLAGS="$(TARGET_CFLAGS)" CXXFLAGS="$(TARGET_CXXFLAGS)" \
	       LDFLAGS="$(TARGET_LDFLAGS)" \
	       $(MAKE) -C $(@D)/ \
	       CC="$(TARGET_CC)" CXX="$(TARGET_CXX)" LD="$(TARGET_CC)" \
	       RANLIB="$(TARGET_RANLIB)" AR="$(TARGET_AR)" \
	       platform="$(LIBRETRO_PLATFORM)"
endef

define LIBRETRO_GPSP_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/gpsp_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/gpsp_libretro.so
endef

$(eval $(generic-package))
