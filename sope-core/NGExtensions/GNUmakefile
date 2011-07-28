# GNUstep makefile

include ../../config.make
include ../common.make

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGExtensions
else
FRAMEWORK_NAME = NGExtensions
endif

libNGExtensions_PCH_FILE = common.h
libNGExtensions_DLL_DEF = libNGExtensions.def
libNGExtensions_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGExtensions_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libNGExtensions_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGExtensions_HEADER_FILES_DIR	 = ./NGExtensions
libNGExtensions_HEADER_FILES_INSTALL_DIR = /NGExtensions

libNGExtensions_HEADER_FILES = \
	NGExtensionsDecls.h			\
	NGExtensions.h				\
	AutoDefines.h				\
	IndexFunc.h				\
	NGBase64Coding.h			\
	NGBaseTypes.h				\
	NGBitSet.h				\
	NGBundleManager.h			\
	NGCharBuffers.h				\
	NGCustomFileManager.h			\
	NGDirectoryEnumerator.h			\
	NGFileFolderInfoDataSource.h		\
	NGFileManager.h				\
	NGFileManagerURL.h			\
	NGHashMap.h				\
	NGMemoryAllocation.h			\
	NGMerging.h				\
	NGQuotedPrintableCoding.h		\
	NGStack.h				\
	NGObjectMacros.h			\
	NGCalendarDateRange.h			\
	NGResourceLocator.h			\

libNGExtensions_OBJC_FILES = \
	NGExtensions.m				\
	NGBase64Coding.m			\
	NGBitSet.m				\
	NGBundleManager.m			\
	NGCustomFileManager.m			\
	NGDirectoryEnumerator.m			\
	NGFileFolderInfoDataSource.m		\
	NGFileManager.m				\
	NGFileManager+JS.m			\
	NGFileManagerURL.m			\
	NGHashMap.m				\
	NGMerging.m				\
	NGQuotedPrintableCoding.m		\
	NGStack.m				\
	NGCalendarDateRange.m			\
	NGResourceLocator.m			\

ifeq ($(FOUNDATION_LIB), apple)
libNGExtensions_OBJC_FILES += FileObjectHolder.m
endif

libNGExtensions_SUBPROJECTS = \
	FdExt.subproj		\
	EOExt.subproj		\
	XmlExt.subproj		\
	NGRuleEngine.subproj	\
	NGLogging.subproj	\

EOExt_HEADER_FILES = \
	EOCacheDataSource.h		\
	EOCompoundDataSource.h		\
	EODataSource+NGExtensions.h	\
	EOFilterDataSource.h		\
	EOGrouping.h			\
	EOGroupingSet.h			\
	EOKeyGrouping.h			\
	EOKeyMapDataSource.h		\
	EOQualifier+CtxEval.h		\
	EOQualifierGrouping.h		\
	EOTrueQualifier.h		\
	EOQualifier+plist.h		\
	EOSortOrdering+plist.h		\
	EOFetchSpecification+plist.h	\

FdExt_HEADER_FILES = \
	NSArray+enumerator.h		\
	NSAutoreleasePool+misc.h	\
	NSBundle+misc.h			\
	NSCalendarDate+misc.h		\
	NSData+gzip.h			\
	NSData+misc.h			\
	NSDictionary+misc.h		\
	NSEnumerator+misc.h		\
	NSException+misc.h		\
	NSFileManager+Extensions.h	\
	NSNull+misc.h			\
	NSObject+Logs.h			\
	NSObject+Values.h		\
	NSProcessInfo+misc.h		\
	NSRunLoop+FileObjects.h		\
	NSSet+enumerator.h		\
	NSString+Ext.h			\
	NSString+German.h		\
	NSString+Formatting.h		\
	NSString+Encoding.h		\
	NSString+Escaping.h		\
	NSString+misc.h			\
	NSURL+misc.h			\
	NGPropertyListParser.h		\

XmlExt_HEADER_FILES = \
	DOMNode+EOQualifier.h

NGRuleEngine_HEADER_FILES = \
	NGRuleEngine.h		\
	NGRule.h		\
	NGRuleAssignment.h	\
	NGRuleContext.h		\
	NGRuleModel.h		\

NGLogging_HEADER_FILES = \
	NGLogging.h			\
	NGLogLevel.h			\
	NGLogger.h			\
	NGLoggerManager.h		\
	NGLogEvent.h			\
	NGLogEventFormatter.h		\
	NGLogAppender.h			\
	NGLogFileHandleAppender.h	\
	NGLogSyslogAppender.h		\


libNGExtensions_HEADER_FILES += \
	$(FdExt_HEADER_FILES)		\
	$(EOExt_HEADER_FILES)		\
	$(XmlExt_HEADER_FILES)		\
	$(NGRuleEngine_HEADER_FILES)	\
	$(NGLogging_HEADER_FILES)


# framework support

NGExtensions_PCH_FILE         = $(libNGExtensions_PCH_FILE)
NGExtensions_HEADER_FILES_DIR = NGExtensions
NGExtensions_HEADER_FILES     = $(libNGExtensions_HEADER_FILES)
NGExtensions_OBJC_FILES       = $(libNGExtensions_OBJC_FILES)
NGExtensions_SUBPROJECTS      = $(libNGExtensions_SUBPROJECTS)


# building

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
