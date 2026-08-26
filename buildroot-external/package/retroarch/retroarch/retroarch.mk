###############################################################################
#
# retroarch
#
###############################################################################

RETROARCH_VERSION = 08dd2a8f7bdd3881b2139f265670910b3520ac9d
RETROARCH_SITE = $(call github,libretro,RetroArch,$(RETROARCH_VERSION))
RETROARCH_DEPENDENCIES = host-pkgconf

# Panel mounted upside down -- see rotation = <180> in the board DTS.
# Taken from the same Buildroot option the launcher uses so the mounting angle
# is stated once. RetroArch's video_rotation only rotates CORE output; patch
# 0007 uses this to rotate the base projection so the menu and OSD follow too.
RETROARCH_DISPLAY_ROTATION = $(call qstrip,$(BR2_PACKAGE_RETROBPI_LAUNCHER_PANEL_ROTATION))
ifeq ($(RETROARCH_DISPLAY_ROTATION),)
RETROARCH_DISPLAY_ROTATION = 0
endif

RETROARCH_CONF_OPTS += --disable-oss
RETROARCH_CONF_OPTS += --disable-pulse
RETROARCH_CONF_OPTS += --disable-cheevos
RETROARCH_CONF_OPTS += --disable-freetype
RETROARCH_CONF_OPTS += --disable-7zip
RETROARCH_CONF_OPTS += --disable-builtinflac
RETROARCH_CONF_OPTS += --disable-ssl
RETROARCH_CONF_OPTS += --disable-ffmpeg
RETROARCH_CONF_OPTS += --disable-qt

ifeq ($(BR2_PACKAGE_RETROARCH_RGUI),)
	RETROARCH_CONF_OPTS += --disable-rgui
endif

ifeq ($(BR2_PACKAGE_RETROARCH_NETWORKING),)
	RETROARCH_CONF_OPTS += --disable-networking
endif

ifeq ($(BR2_PACKAGE_RETROARCH_HID),)
	RETROARCH_CONF_OPTS += --disable-hid --disable-libusb
endif

ifeq ($(BR2_PACKAGE_RETROARCH_ASSETS),)

define RETRO_ASSETS_INSTALL_TARGET_CMDS
	cp -r  retro-assets  $(TARGET_DIR)/usr/lib/libretro/
endef

endif

ifeq ($(BR2_PACKAGE_ZLIB),y)
	RETROARCH_CONF_OPTS += --enable-zlib
	RETROARCH_DEPENDENCIES += zlib
else
	RETROARCH_CONF_OPTS += --disable-zlib
endif

ifeq ($(BR2_PACKAGE_XLIB_LIBX11),y)
	RETROARCH_CONF_OPTS += --enable-x11
	RETROARCH_DEPENDENCIES += xlib_libX11
else
	RETROARCH_CONF_OPTS += --disable-x11
	RETROARCH_CONF_ENV += HAVE_XCB=no
endif

ifeq ($(BR2_PACKAGE_SDL),y)
	RETROARCH_CONF_OPTS += --enable-sdl
	RETROARCH_DEPENDENCIES += sdl
else
	RETROARCH_CONF_OPTS += --disable-sdl
endif

ifeq ($(BR2_PACKAGE_WAYLAND),y)
	RETROARCH_CONF_OPTS += --enable-wayland
	RETROARCH_DEPENDENCIES += wayland
else
	RETROARCH_CONF_OPTS += --disable-wayland
endif

# Prefer using wayland than sdl2
ifeq ($(BR2_PACKAGE_SDL2):$(BR2_PACKAGE_WAYLAND),y:)
	RETROARCH_CONF_OPTS += --enable-sdl2
	RETROARCH_DEPENDENCIES += sdl2
else
	RETROARCH_CONF_OPTS += --disable-sdl2
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGLES),y)
	RETROARCH_CONF_OPTS += --enable-opengles
	RETROARCH_DEPENDENCIES += libgles
else
	RETROARCH_CONF_OPTS += --disable-opengles
endif

ifeq ($(BR2_PACKAGE_HAS_LIBEGL),y)
	RETROARCH_CONF_OPTS += --enable-egl
	RETROARCH_DEPENDENCIES += libegl
else
	RETROARCH_CONF_OPTS += --disable-egl
endif

ifeq ($(BR2_PACKAGE_HAS_LIBOPENVG),y)
	RETROARCH_DEPENDENCIES += libopenvg
endif

# Plain DRM video driver (software rendering to DRM dumb buffer, no GL needed)
ifeq ($(BR2_PACKAGE_LIBDRM),y)
	RETROARCH_CONF_OPTS += --enable-plain_drm
	RETROARCH_DEPENDENCIES += libdrm
else
	RETROARCH_CONF_OPTS += --disable-plain_drm
endif

ifeq ($(BR2_ARM_CPU_HAS_NEON),y)
	RETROARCH_CONF_OPTS += --enable-neon
endif

ifeq ($(BR2_GCC_TARGET_FLOAT_ABI),"hard")
	RETROARCH_CONF_OPTS += --enable-floathard
endif

define RETROARCH_CONFIGURE_CMDS
	(cd $(@D); rm -rf config.cache; \
		$(TARGET_CONFIGURE_ARGS) \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS) -DRETROBPI_DISPLAY_ROTATION=$(RETROARCH_DISPLAY_ROTATION)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		CROSS_COMPILE=$(TARGET_CROSS) \
		PKG_CONF_PATH="$(PKG_CONFIG_HOST_BINARY)" \
		PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"	\
		PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig" \
		$(RETROARCH_CONF_ENV) \
		./configure \
		--prefix=/usr \
		$(RETROARCH_CONF_OPTS) \
	)
endef

define RETROARCH_FIX_DRM_INCLUDE
	sed -i "s|-I/usr/include/libdrm|$(shell $(PKG_CONFIG_HOST_BINARY) --cflags libdrm)|g" $(@D)/Makefile.common
endef
RETROARCH_POST_CONFIGURE_HOOKS += RETROARCH_FIX_DRM_INCLUDE


# Install wrapper script that sets HOME=/root for config file discovery
define RETROARCH_INSTALL_WRAPPER
	mv $(TARGET_DIR)/usr/bin/retroarch $(TARGET_DIR)/usr/bin/retroarch.bin
	printf '#!/bin/sh\nexport HOME=/root\nexec /usr/bin/retroarch.bin --verbose "$$@" 2>>/tmp/retroarch_verbose.log\n' > $(TARGET_DIR)/usr/bin/retroarch
	chmod +x $(TARGET_DIR)/usr/bin/retroarch
endef
RETROARCH_POST_INSTALL_TARGET_HOOKS += RETROARCH_INSTALL_WRAPPER

$(eval $(autotools-package))

# DEFINITION OF LIBRETRO PLATFORM
LIBRETRO_PLATFORM += buildroot

ifeq ($(BR2_PACKAGE_HAS_LIBEGL),y)
	LIBRETRO_PLATFORM += gles
endif

ifeq ($(BR2_ARM_CPU_ARMV4),y)
	LIBRETRO_PLATFORM += armv4
else ifeq ($(BR2_ARM_CPU_ARMV5),y)
	LIBRETRO_PLATFORM += armv5
else ifeq ($(BR2_ARM_CPU_ARMV6),y)
	LIBRETRO_PLATFORM += armv6
else ifeq ($(BR2_ARM_CPU_ARMV7A),y)
	LIBRETRO_PLATFORM += armv7
else ifeq ($(BR2_arm),y)
	LIBRETRO_PLATFORM += armv7
else ifeq ($(BR2_aarch64),y)
	LIBRETRO_PLATFORM += armv8
endif

ifeq ($(BR2_GCC_TARGET_FLOAT_ABI),"hard")
	LIBRETRO_PLATFORM += hardfloat
endif

ifeq ($(BR2_ARM_CPU_HAS_NEON),y)
	LIBRETRO_PLATFORM += neon
endif
