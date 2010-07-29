# GNUstep makefile

SKYROOT=..

include $(GNUSTEP_MAKEFILES)/common.make
include $(SKYROOT)/Version
-include ./Version

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)

ADDITIONAL_CPPFLAGS += -pipe -Wall -Wno-protocol

SOPEDIR="../.."

ADDITIONAL_INCLUDE_DIRS += \
	-I..	\
	-I$(SOPEDIR)/sope-xml			\
	-I$(SOPEDIR)/sope-core			\
	-I$(SOPEDIR)/sope-core/NGExtensions

ADDITIONAL_LIB_DIRS += \
        -L./$(GNUSTEP_OBJ_DIR)			\
	-L$(SOPEDIR)/sope-xml/SaxObjC/$(GNUSTEP_OBJ_DIR)	\
	-L$(SOPEDIR)/sope-xml/DOM/$(GNUSTEP_OBJ_DIR)		\
	-L$(SOPEDIR)/sope-core/EOControl/$(GNUSTEP_OBJ_DIR)	\
	-L$(SOPEDIR)/sope-core/NGExtensions/$(GNUSTEP_OBJ_DIR)

