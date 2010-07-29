# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version
include ../Version

SUBPROJECT_NAME = FoundationExt

FoundationExt_OBJC_FILES = \
	DefaultScannerHandler.m	\
	PrintfFormatScanner.m	\
	FormatScanner.m		\

ADDITIONAL_INCLUDE_DIRS += -I. -I.. -I../../../sope-core/NGExtensions

include $(GNUSTEP_MAKEFILES)/subproject.make
