# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

BUNDLE_NAME        = iCalSaxDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/SaxDrivers-$(MAJOR_VERSION).$(MINOR_VERSION)/

iCalSaxDriver_OBJC_FILES = \
	ICalSaxParser.m		\
	NSCalendarDate+ICal.m	\
	NSString+ICal.m		\

iCalSaxDriver_RESOURCE_FILES = bundle-info.plist

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
-include fhs.make
