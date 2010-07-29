# GNUstep makefile

include ../../config.make
include ../common.make

ifneq ($(frameworks),yes)
LIBRARY_NAME   = libDOM
else
FRAMEWORK_NAME = DOM
DOM_RESOURCE_FILES += Version
endif

libDOM_PCH_FILE = common.h
DOM_PCH_FILE = common.h

LDOM_HEADER_FILES += \
	DOM.h				\
	DOMProtocols.h			\
	DOMAttribute.h			\
	DOMCDATASection.h		\
	DOMCharacterData.h		\
	DOMComment.h			\
	DOMDocument.h			\
	DOMDocumentFragment.h		\
	DOMDocumentType.h		\
	DOMElement.h			\
	DOMEntity.h			\
	DOMEntityReference.h		\
	DOMImplementation.h		\
	DOMNode.h			\
	DOMNotation.h			\
	DOMProcessingInstruction.h	\
	DOMBuilder.h			\
	DOMBuilderFactory.h		\

EDOM_HEADER_FILES += \
	EDOM.h				\
	DOMNode+Enum.h			\
	DOMNode+QueryPath.h		\
	DOMQueryPathExpression.h	\

libDOM_HEADER_FILES = \
	$(LDOM_HEADER_FILES)		\
	$(EDOM_HEADER_FILES)		\
	DOMSaxBuilder.h			\
	DOMSaxHandler.h			\
	DOMText.h			\
	DOMXMLOutputter.h		\
	DOMPYXOutputter.h		\
	DOMNodeWalker.h			\
	DOMNamedNodeMap.h		\

DOM_CORE_OBJC_FILES = \
	NSObject+StringValue.m		\
	DOMAttribute.m			\
	DOMCDATASection.m		\
	DOMCharacterData.m		\
	DOMComment.m			\
	DOMDocument.m			\
	DOMElement.m			\
	DOMEntity.m			\
	DOMEntityReference.m		\
	DOMImplementation.m		\
	DOMNode.m			\
	DOMNodeWithChildren.m		\
	DOMNotation.m			\
	DOMProcessingInstruction.m	\
	DOMText.m			\
	DOMDocument+factory.m		\
	DOMDocumentType.m		\
	DOM+JS.m			\
	DOMBuilderFactory.m		\

EDOM_OBJC_FILES = \
	DOMNode+Enum.m			\
	DOMNode+QueryPath.m		\
	DOMQueryPathExpression.m	\
	NSObject+QPEval.m		\
	DOMNode+QPEval.m		\

DOM_TRAVERSAL_OBJC_FILES = \
	DOMTreeWalker.m			\
	DOMNodeFilter.m			\
	DOMNodeIterator.m		\

libDOM_OBJC_FILES = \
	DOMSaxBuilder.m			\
	DOMSaxHandler.m			\
	DOMXMLOutputter.m		\
	DOMPYXOutputter.m		\
	DOMNodeWalker.m			\
	NSObject+DOM.m			\
	$(EDOM_OBJC_FILES)		\
	$(DOM_CORE_OBJC_FILES)		\
	$(DOM_TRAVERSAL_OBJC_FILES)	\


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
