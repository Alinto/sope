# GNUstep makefile

include ../../../config.make
include ../../common.make

SUBPROJECT_NAME = EOExt

EOExt_PCH_FILE = common.h

EOExt_OBJC_FILES = \
	EOCacheDataSource.m		\
	EOCompoundDataSource.m		\
	EODataSource+NGExtensions.m	\
	EOFetchSpecification+plist.m	\
	EOFilterDataSource.m		\
	EOGrouping.m			\
	EOGroupingSet.m			\
	EOKeyGrouping.m			\
	EOKeyMapDataSource.m		\
	EOQualifier+CtxEval.m		\
	EOQualifier+plist.m		\
	EOQualifierGrouping.m		\
	EOSortOrdering+plist.m		\
	EOTrueQualifier.m		\
	NSArray+EOGrouping.m		\
	EOGlobalID+Ext.m		\

ADDITIONAL_INCLUDE_DIRS += -I. -I.. -I../NGExtensions/ \
	-I../FdExt.subproj/	\
	-I../..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
