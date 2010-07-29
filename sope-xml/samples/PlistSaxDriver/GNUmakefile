# GNUstep Makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME        = PlistSaxDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = $(GNUSTEP_USER_ROOT)/Library/Bundles

PlistSaxDriver_OBJC_FILES = \
	PlistSaxDriver.m

PlistSaxDriver_BUNDLE_LIBS += -lSaxObjC

PlistSaxDriver_RESOURCE_FILES = bundle-info.plist

ADDITIONAL_INCLUDE_DIRS += -I../.. -I..

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
