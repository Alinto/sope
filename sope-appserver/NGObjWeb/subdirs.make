# common settings for SOPE subdirs

include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version
include ../Version

ADDITIONAL_CPPFLAGS += \
        -Wall -DCOMPILE_FOR_GSTEP_MAKE=1        \
        -DSOPE_MAJOR_VERSION=$(MAJOR_VERSION)   \
        -DSOPE_MINOR_VERSION=$(MINOR_VERSION)   \
        -DSOPE_SUBMINOR_VERSION=$(SUBMINOR_VERSION)

ADDITIONAL_INCLUDE_DIRS += \
	-I..			\
	-I../DynamicElements/	\
	-I../..			\
	-I../../../sope-core			\
	-I../../../sope-core/NGStreams		\
	-I../../../sope-core/NGExtensions	\
	-I../../../sope-xml
