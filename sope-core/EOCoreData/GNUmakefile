# GNUstep makefile

include ../../config.make
include ../common.make

ifneq ($(frameworks),yes)
LIBRARY_NAME = libEOCoreData
else
FRAMEWORK_NAME = EOCoreData
endif

libEOCoreData_PCH_FILE = common.h
libEOCoreData_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libEOCoreData_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libEOCoreData_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libEOCoreData_HEADER_FILES_DIR         = .
libEOCoreData_HEADER_FILES_INSTALL_DIR = /EOCoreData


# headers

libEOCoreData_HEADER_FILES += \
	EOCoreData.h	\
	EOCoreDataSource.h		\
	\
	EOFetchSpecification+CoreData.h	\
	EOQualifier+CoreData.h		\
	EOSortOrdering+CoreData.h	\

libEOCoreData_HEADER_FILES += \
	NSExpression+EO.h		\
	NSPredicate+EO.h		\
	NSEntityDescription+EO.h	\
	NSAttributeDescription+EO.h	\
	NSRelationshipDescription+EO.h	\


# implementations

libEOCoreData_OBJC_FILES += \
	EOCoreDataSource.m			\
	\
	EOFetchSpecification+CoreData.m		\
	EOQualifier+CoreData.m			\
	EOSortOrdering+CoreData.m		\
	EOKeyValueQualifier+CoreData.m		\
	EOKeyComparisonQualifier+CoreData.m	\
	EOCompoundQualifiers.m			\

libEOCoreData_OBJC_FILES += \
	NSExpression+EO.m			\
	NSPredicate+EO.m			\
	NSEntityDescription+EO.m		\
	NSAttributeDescription+EO.m		\
	NSRelationshipDescription+EO.m		\
	NSManagedObject+KVC.m			\

libEOCoreData_OBJC_FILES += \
	NSString+CoreData.m

# framework support
EOCoreData_PCH_FILE     = $(libEOCoreData_PCH_FILE)
EOCoreData_HEADER_FILES = $(libEOCoreData_HEADER_FILES)
EOCoreData_OBJC_FILES   = $(libEOCoreData_OBJC_FILES)


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
