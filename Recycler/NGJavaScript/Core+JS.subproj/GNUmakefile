# $Id$

include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = CoreJS

CoreJS_HEADER_FILES_DIR         = .
CoreJS_HEADER_FILES_INSTALL_DIR = /NGJavaScript

CoreJS_HEADER_FILES = \
	NSObject+JS.h		\
	NSString+JS.h		\
	EOJavaScriptGrouping.h	\

CoreJS_OBJC_FILES = \
	EONull+JS.m		\
	NSArray+JS.m		\
	NSDictionary+JS.m	\
	NSNumber+JS.m		\
	NSObject+JS.m		\
	NSString+JS.m		\
	NSUserDefaults+JS.m	\
	NSDate+JS.m		\
	NGFileManager+JS.m	\
	EODataSource+JS.m	\
	EOJavaScriptGrouping.m	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
