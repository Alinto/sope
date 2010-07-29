# GNUstep makefile

SKYROOT=..

include $(GNUSTEP_MAKEFILES)/common.make
include $(SKYROOT)/Version
-include ./Version

ADDITIONAL_CPPFLAGS += -pipe -Wall -Wno-protocol
ifeq ($(reentrant),yes)
ADDITIONAL_CPPFLAGS += -D_REENTRANT=1
endif

ADDITIONAL_INCLUDE_DIRS += \
	-I.. -I../NGStreams/	\
	-I../../sope-xml

ADDITIONAL_LIB_DIRS += \
        -L./$(GNUSTEP_OBJ_DIR)				\
	-L../../sope-xml/SaxObjC/$(GNUSTEP_OBJ_DIR)	\
	-L../../sope-xml/DOM/$(GNUSTEP_OBJ_DIR)		\
	-L../../sope-xml/XmlRpc/$(GNUSTEP_OBJ_DIR)

ifeq ($(FOUNDATION_LIB),nx)
ADDITIONAL_LDFLAGS += -framework Foundation
endif
