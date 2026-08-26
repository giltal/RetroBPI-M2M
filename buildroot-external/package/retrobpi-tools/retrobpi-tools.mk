################################################################################
#
# retrobpi-tools
#
# Small on-target helpers that live in <project>/tools.
#
################################################################################

RETROBPI_TOOLS_VERSION = local
RETROBPI_TOOLS_SITE = $(BR2_EXTERNAL_RETROBPI_PATH)/../tools
RETROBPI_TOOLS_SITE_METHOD = local
RETROBPI_TOOLS_LICENSE = GPL-2.0

RETROBPI_TOOLS_PROGS = inject-input

define RETROBPI_TOOLS_BUILD_CMDS
	$(foreach p,$(RETROBPI_TOOLS_PROGS), \
		$(TARGET_CC) $(TARGET_CFLAGS) -O2 -Wall -o $(@D)/$(p) $(@D)/$(p).c
	)
endef

define RETROBPI_TOOLS_INSTALL_TARGET_CMDS
	$(foreach p,$(RETROBPI_TOOLS_PROGS), \
		$(INSTALL) -D -m 0755 $(@D)/$(p) $(TARGET_DIR)/usr/bin/$(p)
	)
endef

$(eval $(generic-package))
