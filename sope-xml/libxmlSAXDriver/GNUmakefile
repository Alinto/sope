# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

BUNDLE_NAME        = libxmlSAXDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/SaxDrivers-$(MAJOR_VERSION).$(MINOR_VERSION)/

libxmlSAXDriver_PCH_FILE = common.h

libxmlSAXDriver_OBJC_FILES = \
	libxmlSAXDriver.m	\
	libxmlHTMLSAXDriver.m	\
	libxmlDocSAXDriver.m	\
	libxmlSAXLocator.m	\
	TableCallbacks.m	\

libxmlSAXDriver_RESOURCE_FILES = bundle-info.plist Version
libxmlSAXDriver_LOCALIZED_RESOURCE_FILES =

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
-include fhs.make
