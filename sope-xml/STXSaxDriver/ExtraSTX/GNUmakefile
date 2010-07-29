# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = ExtraSTX

ExtraSTX_PCH_FILE = common.h

ExtraSTX_OBJC_FILES = \
	NSString+STX.m		\
	StructuredLine.m	\
	StructuredStack.m	\
	StructuredText.m	\

ADDITIONAL_INCLUDE_DIRS += -I. -I../Model -I..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
