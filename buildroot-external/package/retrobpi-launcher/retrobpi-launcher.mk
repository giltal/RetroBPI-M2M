################################################################################
#
# retrobpi-launcher
#
################################################################################

RETROBPI_LAUNCHER_VERSION = local
RETROBPI_LAUNCHER_SITE = $(BR2_EXTERNAL_RETROBPI_PATH)/../launcher
RETROBPI_LAUNCHER_SITE_METHOD = local
RETROBPI_LAUNCHER_LICENSE = GPL-2.0
RETROBPI_LAUNCHER_DEPENDENCIES = libdrm sdl2 sdl2_ttf sdl2_image libpng freetype

RETROBPI_LAUNCHER_PANEL_W = $(call qstrip,$(BR2_PACKAGE_RETROBPI_LAUNCHER_PANEL_W))
RETROBPI_LAUNCHER_PANEL_H = $(call qstrip,$(BR2_PACKAGE_RETROBPI_LAUNCHER_PANEL_H))
RETROBPI_LAUNCHER_PANEL_ROTATION = $(call qstrip,$(BR2_PACKAGE_RETROBPI_LAUNCHER_PANEL_ROTATION))

define RETROBPI_LAUNCHER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		STRIP="$(TARGET_STRIP)" \
		SYSROOT="$(STAGING_DIR)" \
		PANEL_W=$(RETROBPI_LAUNCHER_PANEL_W) \
		PANEL_H=$(RETROBPI_LAUNCHER_PANEL_H) \
		PANEL_ROTATION=$(RETROBPI_LAUNCHER_PANEL_ROTATION)
endef

define RETROBPI_LAUNCHER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/retrobpi_launcher \
		$(TARGET_DIR)/usr/bin/retrobpi_launcher
endef

$(eval $(generic-package))
