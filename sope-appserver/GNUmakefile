# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=sope-appserver
VERSION=4.5.0

SUBPROJECTS += \
	NGObjWeb	\
	WEExtensions	\
	WOExtensions


ifeq ($(frameworks),yes)
include umbrella.make
endif

# project makefiles

-include $(GNUSTEP_MAKEFILES)/GNUmakefile.preamble

ifneq ($(only_umbrella),yes)
include $(GNUSTEP_MAKEFILES)/aggregate.make
endif

ifeq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/framework.make
endif

-include $(GNUSTEP_MAKEFILES)/GNUmakefile.postamble


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh $(PACKAGE_NAME)
