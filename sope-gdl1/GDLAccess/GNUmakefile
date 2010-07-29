# GNUstep makefile

include ../../config.make
include ../common.make
-include ../Version
-include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libGDLAccess
else
FRAMEWORK_NAME = GDLAccess
endif

libGDLAccess_PCH_FILE = common.h
libGDLAccess_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libGDLAccess_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libGDLAccess_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libGDLAccess_DLL_DEF = libGDLAccess.def

libGDLAccess_HEADER_FILES = \
	GDLAccess.h			\
	EODelegateResponse.h		\
	EOJoinTypes.h			\
	EOAdaptor.h			\
	EOAdaptorChannel.h		\
	EOAdaptorContext.h		\
	EOArrayProxy.h			\
	EOAttribute.h			\
	EOAttributeOrdering.h		\
	EOCustomValues.h		\
	EODatabase.h			\
	EODatabaseChannel.h		\
	EODatabaseContext.h		\
	EOEntity.h			\
	EOExpressionArray.h		\
	EOFExceptions.h			\
	EODatabaseFault.h		\
	EODatabaseFaultResolver.h	\
	EOModel.h			\
	EOObjectUniquer.h		\
	EOPrimaryKeyDictionary.h	\
	EOSQLQualifier.h		\
	EOQuotedExpression.h		\
	EORelationship.h		\
	EOSQLExpression.h		\
	EOGenericRecord.h		\
	EOModelGroup.h			\
	EONull.h			\
	EOKeySortOrdering.h		\
	EOAdaptorDataSource.h 		\
	EOAdaptorChannel+Attributes.h	\
	EOAdaptorOperation.h		\
	EOAdaptorGlobalID.h		\
	NSObject+EONullInit.h		\
	EOEntity+Factory.h		\
	EORecordDictionary.h		\
	EOFault.h			\
	EOFaultHandler.h		\

libGDLAccess_OBJC_FILES = \
	eoaccess.m			\
	EOAdaptor.m			\
	EOAdaptorChannel.m		\
	EOAdaptorContext.m		\
	EOArrayProxy.m			\
	EOAttribute.m			\
	EOAttributeOrdering.m		\
	EOCustomValues.m		\
	EODatabase.m			\
	EODatabaseChannel.m		\
	EODatabaseContext.m		\
	EOEntity.m			\
	EOExpressionArray.m		\
	EOFExceptions.m			\
	EODatabaseFault.m		\
	EODatabaseFaultResolver.m	\
	EOKeySortOrdering.m		\
	EOModel.m			\
	EOObjectUniquer.m		\
	EOPrimaryKeyDictionary.m	\
	EORelationship.m		\
	EOGenericRecord.m		\
	EOModelGroup.m			\
	EOEntityClassDescription.m	\
	EOAdaptorDataSource.m 		\
	EOAdaptorChannel+Attributes.m	\
	EOAdaptorOperation.m		\
	EOAdaptorGlobalID.m		\
	NSObject+EONullInit.m		\
	EOEntity+Factory.m		\
	EORecordDictionary.m		\
	EOFault.m			\
	EOFaultHandler.m		\
	\
	EOAndQualifier+SQL.m		\
	EOKeyComparisonQualifier+SQL.m	\
	EOKeyValueQualifier+SQL.m	\
	EONotQualifier+SQL.m		\
	EOOrQualifier+SQL.m		\
	EOQualifier+SQL.m		\
	\
	EOSQLQualifier.m		\
	EOSQLExpression.m		\
	EOSelectSQLExpression.m		\
	EOQuotedExpression.m		\
	EOQualifierScanner.m		\

ifneq ($(FOUNDATION_LIB),fd)
libGDLAccess_SUBPROJECTS += FoundationExt
endif

libGDLAccess_HEADER_FILES_DIR         = .
libGDLAccess_HEADER_FILES_INSTALL_DIR = /GDLAccess


# adaptor load test

TOOL_NAME = load-EOAdaptor connect-EOAdaptor

load-EOAdaptor_OBJC_FILES    = load-EOAdaptor.m
connect-EOAdaptor_OBJC_FILES = connect-EOAdaptor.m
load-EOAdaptor_PCH_FILE      = common.h
connect-EOAdaptor_PCH_FILE   = common.h
load-EOAdaptor_INSTALL_DIR	= $(SOPE_TOOLS)/
connect-EOAdaptor_INSTALL_DIR	= $(SOPE_TOOLS)/


# framework support

GDLAccess_PCH_FILE     = $(libGDLAccess_PCH_FILE)
GDLAccess_HEADER_FILES = $(libGDLAccess_HEADER_FILES)
GDLAccess_OBJC_FILES   = $(libGDLAccess_OBJC_FILES)
GDLAccess_SUBPROJECTS  = $(libGDLAccess_SUBPROJECTS)


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
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
