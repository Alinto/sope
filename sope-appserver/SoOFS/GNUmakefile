# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

# TODO: clash between bundle and libname!
ifneq ($(frameworks),yes)
LIBRARY_NAME = libSoOFS
else
FRAMEWORK_NAME = SoOFS
endif


libSoOFS_PCH_FILE = common.h
libSoOFS_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libSoOFS_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libSoOFS_HEADER_FILES_DIR         = .
libSoOFS_HEADER_FILES_INSTALL_DIR = /SoOFS

libSoOFS_HEADER_FILES = \
	SoOFS.h			\
	OFSBaseObject.h		\
	OFSFactoryContext.h	\
	OFSFactoryRegistry.h	\
	OFSFile.h		\
	OFSFileRenderer.h	\
	OFSFolder.h		\
	OFSImage.h		\
	OFSPropertyListObject.h	\
	OFSResourceManager.h	\
	OFSWebMethod.h		\
	OFSWebMethodRenderer.h	\
	OFSWebTemplate.h	\
	OFSWebDocument.h	\
	OFSHttpPasswd.h		\
	OFSChangeLog.h		\
	OFSFolderDataSource.h	\

libSoOFS_OBJC_FILES = \
	OFSBaseObject.m			\
	OFSFactoryContext.m		\
	OFSFactoryRegistry.m		\
	OFSFile.m			\
	OFSFileRenderer.m		\
	OFSFolder+SoDAV.m		\
	OFSFolder.m			\
	OFSFolderClassDescription.m	\
	OFSImage.m			\
	OFSPropertyListObject.m		\
	OFSResourceManager.m		\
	OFSWebMethod.m			\
	OFSWebMethodRenderer.m		\
	OFSWebTemplate.m		\
	OFSWebDocument.m		\
	OFSHttpPasswd.m			\
	OFSChangeLog.m			\
	OFSFolderDataSource.m		\


ifeq ($(frameworks),yes)
# framework support

SoOFS_PCH_FILE        = $(libSoOFS_PCH_FILE)
SoOFS_HEADER_FILES    = $(libSoOFS_HEADER_FILES)
SoOFS_OBJC_FILES      = $(libSoOFS_OBJC_FILES) SoOFSProduct.m
SoOFS_RESOURCE_FILES  = product.plist Version
SoOFS_PRINCIPAL_CLASS = SoOFSProduct

else

# ----- SoCore product for SOPE core registrations

BUNDLE_NAME      = SoOFS
BUNDLE_EXTENSION = .sxp
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/SoProducts-$(MAJOR_VERSION).$(MINOR_VERSION)/

SoOFS_OBJC_FILES       = SoOFSProduct.m
SoOFS_RESOURCE_FILES   = product.plist Version
SoOFS_PRINCIPAL_CLASS  = SoOFSProduct

endif


# ----- NGObjWeb tools

SOPED_NAME=sope-$(MAJOR_VERSION).$(MINOR_VERSION)

TOOL_NAME = $(SOPED_NAME)

$(SOPED_NAME)_OBJC_FILES = sope.m


-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make
