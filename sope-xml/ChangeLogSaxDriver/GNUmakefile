# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

BUNDLE_NAME        = ChangeLogSaxDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = ${SOPE_SAXDRIVERS}/

ChangeLogSaxDriver_OBJC_FILES =		\
	ChangeLogSaxDriver.m		\
	NSString+Extensions.m		\
	NSCalendarDate+Extensions.m

ChangeLogSaxDriver_RESOURCE_FILES = bundle-info.plist default.locale


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
