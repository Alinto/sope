# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = WOHttpAdaptor

WOHttpAdaptor_PCH_FILE = common.h

WOHttpAdaptor_OBJC_FILES = \
	WOHttpAdaptor.m		\
	WORecordRequestStream.m	\
	WOHttpTransaction.m	\
	WORequest+Adaptor.m	\
	WORequestParser.m	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
