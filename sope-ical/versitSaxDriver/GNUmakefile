# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

BUNDLE_NAME        = versitSaxDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/SaxDrivers-$(MAJOR_VERSION).$(MINOR_VERSION)/

versitSaxDriver_PRINCIPAL_CLASS = VSSaxDriver

versitSaxDriver_PCH_FILE = common.h

versitSaxDriver_OBJC_FILES =	\
	VSSaxDriver.m		\
	VSiCalSaxDriver.m	\
	VSvCardSaxDriver.m	\
	VSStringFormatter.m	\

versitSaxDriver_RESOURCE_FILES = bundle-info.plist

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
-include fhs.make
