# GNUstep makefile

-include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(FOUNDATION_LIB),apple)
ifeq ($(frameworks),yes)

SUBPROJECTS += \
	SOPEX

include $(GNUSTEP_MAKEFILES)/aggregate.make


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh "SOPE:X"

endif
endif
