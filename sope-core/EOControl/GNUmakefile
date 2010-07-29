# GNUstep makefile

include ../../config.make
include ../common.make

ifneq ($(frameworks),yes)
LIBRARY_NAME = libEOControl
else
FRAMEWORK_NAME = EOControl
endif

libEOControl_PCH_FILE = common.h
libEOControl_DLL_DEF = libEOControl.def
libEOControl_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libEOControl_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libEOControl_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libEOControl_HEADER_FILES_DIR         = .
libEOControl_HEADER_FILES_INSTALL_DIR = /EOControl

libEOControl_HEADER_FILES = \
	EOArrayDataSource.h		\
	EOClassDescription.h		\
	EOControl.h			\
	EOControlDecls.h		\
	EODataSource.h			\
	EODetailDataSource.h		\
	EOFetchSpecification.h		\
	EOGenericRecord.h		\
	EOGlobalID.h			\
	EOKeyGlobalID.h			\
	EOKeyValueArchiver.h		\
	EOKeyValueCoding.h		\
	EONull.h			\
	EOObserver.h			\
	EOQualifier.h			\
	EOSortOrdering.h		\
	EOSQLParser.h			\

libEOControl_OBJC_FILES = \
	EOAndQualifier.m		\
	EOArrayDataSource.m		\
	EOClassDescription.m		\
	EODataSource.m			\
	EODetailDataSource.m		\
	EOFetchSpecification.m		\
	EOGenericRecord.m		\
	EOGlobalID.m			\
	EOKeyComparisonQualifier.m	\
	EOKeyGlobalID.m			\
	EOKeyValueArchiver.m		\
	EOKeyValueCoding.m		\
	EOKeyValueQualifier.m		\
	EONotQualifier.m		\
	EONull.m			\
	EOObserver.m			\
	EOOrQualifier.m			\
	EOQualifier.m			\
	EOQualifierParser.m		\
	EOSortOrdering.m		\
	EOValidation.m			\
	NSArray+EOQualifier.m		\
	NSObject+EOQualifierOps.m	\
	EOSQLParser.m			\
	EOQualifierVariable.m		\
	NSObject+QualDesc.m		\

# framework support
EOControl_PCH_FILE     = $(libEOControl_PCH_FILE)
EOControl_HEADER_FILES = $(libEOControl_HEADER_FILES)
EOControl_OBJC_FILES   = $(libEOControl_OBJC_FILES)


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
