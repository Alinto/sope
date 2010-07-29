# GNUstep makefile

include ../../config.make
include ../common.make

ifneq ($(frameworks),yes)
LIBRARY_NAME   = libSaxObjC
else
FRAMEWORK_NAME = SaxObjC
SaxObjC_RESOURCE_FILES += Version
endif

libSaxObjC_PCH_FILE = common.h
SaxObjC_PCH_FILE = common.h

libSaxObjC_OBJC_FILES = \
	SaxAttributeList.m		\
	SaxAttributes.m			\
	SaxDefaultHandler.m		\
	SaxException.m			\
	SaxHandlerBase.m		\
	SaxLocator.m			\
	SaxMethodCallHandler.m		\
	SaxNamespaceSupport.m		\
	SaxObjectDecoder.m		\
	SaxObjectModel.m		\
	SaxXMLFilter.m			\
	SaxXMLReaderFactory.m		\

libSaxObjC_HEADER_FILES = \
	SaxObjC.h			\
	SaxAttributeList.h		\
	SaxAttributes.h			\
	SaxContentHandler.h		\
	SaxDTDHandler.h			\
	SaxDeclHandler.h		\
	SaxDefaultHandler.h		\
	SaxDocumentHandler.h		\
	SaxEntityResolver.h		\
	SaxErrorHandler.h		\
	SaxException.h			\
	SaxHandlerBase.h		\
	SaxLexicalHandler.h		\
	SaxLocator.h			\
	SaxNamespaceSupport.h		\
	SaxObjectDecoder.h		\
	SaxObjectModel.h		\
	SaxXMLFilter.h			\
	SaxXMLReader.h			\
	SaxXMLReaderFactory.h		\
	SaxMethodCallHandler.h		\
	XMLNamespaces.h			\

libSaxObjC_PCH_FILE = common.h

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
