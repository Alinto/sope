# GNUstep makefile

-include ../../../config.make

include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = SBJson

SBJson_VERSION=2.3.1

SBJson_INCLUDE_DIRS = -std=gnu99

SBJson_HEADER_FILES = \
	SBJson.h \
	NSObject+SBJSON.h \
	NSString+SBJSON.h \
	SBJsonBase.h \
	SBJsonParser.h \
	SBJsonWriter.h

SBJson_OBJC_FILES = \
	NSObject+SBJSON.m \
	NSString+SBJSON.m \
	SBJsonBase.m \
	SBJsonParser.m \
	SBJsonWriter.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
