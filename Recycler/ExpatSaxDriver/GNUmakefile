# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

BUNDLE_NAME        = ExpatSaxDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/SaxDrivers-$(MAJOR_VERSION).$(MINOR_VERSION)/

ExpatSaxDriver_OBJC_FILES = \
	ExpatSaxDriver.m	\

ExpatSaxDriver_BUNDLE_LIBS += -lSaxObjC -lexpat

ExpatSaxDriver_RESOURCE_FILES = bundle-info.plist

ADDITIONAL_INCLUDE_DIRS += -I/usr/local/include

ifneq ($(GNUSTEP_BUILD_DIR),)
ADDITIONAL_LIB_DIRS += \
	-L$(GNUSTEP_BUILD_DIR)/../SaxObjC/$(GNUSTEP_OBJ_DIR_NAME)
else
ADDITIONAL_LIB_DIRS += -L../SaxObjC/$(GNUSTEP_OBJ_DIR)
endif

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

ifneq ($(GNUSTEP_BUILD_DIR),)
after-all ::
	@(cp bundle-info.plist \
	  $(GNUSTEP_BUILD_DIR)/$(BUNDLE_NAME)$(BUNDLE_EXTENSION))
else
after-all ::
	@(cd $(BUNDLE_NAME)$(BUNDLE_EXTENSION);\
	  cp ../bundle-info.plist .)
endif

SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib
