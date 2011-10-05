# GNUstep makefile

include ../../../config.make
include ../../common.make

SUBPROJECT_NAME = FdExt

FdExt_PCH_FILE = common.h

FdExt_OBJC_FILES = \
	NSArray+enumerator.m		\
	NSAutoreleasePool+misc.m	\
	NSBundle+misc.m			\
	NSCalendarDate+misc.m		\
	NSCalendarDate+matrix.m		\
	NSData+gzip.m			\
	NSData+misc.m			\
	NSDictionary+KVC.m		\
	NSDictionary+misc.m		\
	NSEnumerator+misc.m		\
	NSException+misc.m		\
	NSFileManager+Extensions.m	\
	NSNull+misc.m			\
	NSObject+Logs.m			\
	NSObject+Values.m		\
	NSProcessInfo+misc.m		\
	NSRunLoop+FileObjects.m		\
	NSSet+enumerator.m		\
	NSString+Ext.m			\
	NSString+Encoding.m		\
	NSString+Escaping.m		\
	NSString+Formatting.m		\
	NSString+misc.m			\
	NSString+HTMLEscaping.m		\
	NSString+XMLEscaping.m		\
	NSString+URLEscaping.m		\
	NSString+German.m		\
	NSURL+misc.m			\
	NGPropertyListParser.m		\

ADDITIONAL_INCLUDE_DIRS += -I. -I../NGExtensions/ -I.. -I../..

ifeq ($(iseries),yes)
ADDITIONAL_CPPFLAGS += -DISERIES=1
endif

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
