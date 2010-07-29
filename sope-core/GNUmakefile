# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=sope-core
VERSION=4.5.0

SUBPROJECTS += \
	EOControl	\
	NGExtensions	\
	NGStreams

# compile EOCoreData if we are on Tiger
ifeq ($(findstring darwin8, $(GNUSTEP_TARGET_OS)), darwin8)
SUBPROJECTS += EOCoreData
endif


ifeq ($(frameworks),yes)
include umbrella.make
endif

# project makefiles

include $(GNUSTEP_MAKEFILES)/aggregate.make
ifeq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/framework.make
endif


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh $(PACKAGE_NAME)
