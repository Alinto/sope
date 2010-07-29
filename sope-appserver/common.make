# GNUstep makefile

include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
-include ./Version

ADDITIONAL_CPPFLAGS += -pipe -Wall -Wno-protocol

ADDITIONAL_INCLUDE_DIRS += \
	-I..				\
	-I../../sope-core/		\
	-I../../sope-core/NGExtensions	\
	-I../../sope-core/NGStreams	\
	-I../../sope-xml

ADDITIONAL_LIB_DIRS += \
	-L./$(GNUSTEP_OBJ_DIR)	\
	-L../../sope-core/EOControl/$(GNUSTEP_OBJ_DIR)		\
	-L../../sope-core/NGExtensions/$(GNUSTEP_OBJ_DIR)	\
	-L../../sope-core/NGStreams/$(GNUSTEP_OBJ_DIR)		\
	-L../../sope-xml/SaxObjC/$(GNUSTEP_OBJ_DIR)		\
	-L../../sope-xml/DOM/$(GNUSTEP_OBJ_DIR)			\

ifeq ($(FOUNDATION_LIB),nx)
ADDITIONAL_LDFLAGS += -framework Foundation
endif
