# GNUstep makefile

SKYROOT=..

include $(GNUSTEP_MAKEFILES)/common.make
include $(SKYROOT)/Version
-include ./Version

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)

ADDITIONAL_CPPFLAGS += -pipe -Wall -Wno-protocol

ADDITIONAL_INCLUDE_DIRS += -I..

ADDITIONAL_LIB_DIRS += \
        -L./$(GNUSTEP_OBJ_DIR)			\
	-L../SaxObjC/$(GNUSTEP_OBJ_DIR)		\

ifeq ($(FOUNDATION_LIB),nx)
ADDITIONAL_LDFLAGS += -framework Foundation
endif
