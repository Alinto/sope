# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

BUNDLE_NAME        = pyxSAXDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = $(GNUSTEP_USER_ROOT)/Library/SaxDrivers-$(SOPE_MAJOR_VERSION).$(SOPE_MINOR_VERSION)/

pyxSAXDriver_OBJC_FILES = pyxSAXDriver.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
-include fhs.make
