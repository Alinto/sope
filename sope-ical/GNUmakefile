# GNUstep makefile

-include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=sope-ical
VERSION=4.5.0

SUBPROJECTS += \
	versitSaxDriver	\
	NGiCal

ifeq ($(libical),yes)
SUBPROJECTS += iCalSaxDriver
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh sope-ical
