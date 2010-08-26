# GNUstep makefile

include ../../config.make
include ../common.make
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME   = libNGObjWeb
else
FRAMEWORK_NAME = NGObjWeb
endif


ifneq ($(frameworks),yes)
RESOURCES_DIR = $(SOPE_NGOBJWEB)/
endif

libNGObjWeb_PCH_FILE = common.h
libNGObjWeb_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGObjWeb_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libNGObjWeb_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGObjWeb_SUBPROJECTS = \
	NGHttp		\
	Associations	\
	Templates	\
	DynamicElements	\
	WOHttpAdaptor	\
	SoObjects	\
	WebDAV		\

libNGObjWeb_HEADER_FILES_DIR         = NGObjWeb
libNGObjWeb_HEADER_FILES_INSTALL_DIR = /NGObjWeb

libNGObjWeb_RESOURCES = \
	Defaults.plist		\
	Languages.plist		\
	DAVPropMap.plist	

FHS_MANPAGES += \
	sope-ngobjweb-defaults.5	\
	doc/*.3

libNGObjWeb_HEADER_FILES = \
	NGObjWebDecls.h			\
	NGObjWeb.h			\
	OWResponder.h			\
	OWViewRequestHandler.h		\
	OWResourceManager.h		\
	WEClientCapabilities.h		\
	WOActionResults.h		\
	WOAdaptor.h			\
	WOApplication.h			\
	WOCoreApplication.h		\
	WOAssociation.h			\
	WOComponent.h			\
	WOContext.h			\
	WOCookie.h			\
	WODirectAction.h		\
	WODisplayGroup.h		\
	WODynamicElement.h		\
	WOElement.h			\
	WOHTTPConnection.h		\
	WOMailDelivery.h		\
	WOMessage.h			\
	WORequest.h			\
	WORequestHandler.h		\
	WOResourceManager.h		\
	WOResponse.h			\
	WOSession.h			\
	WOSessionStore.h		\
	WOStatisticsStore.h		\
	WOTemplateBuilder.h		\
        WOxElemBuilder.h		\
	WOTemplate.h			\
	WOComponentScript.h		\
	WOProxyRequestHandler.h		\
	WOPageGenerationContext.h	\
	WOElementTrackingContext.h	\
	WOComponentDefinition.h		\
	NSString+JavaScriptEscaping.h	\
	WOHTMLDynamicElement.h		\
	WOActionURL.h			\

NGObjWebCore_OBJC_FILES = \
	NSObject+WO.m			\
	WOApplication+defaults.m	\
	WOApplication.m			\
	WOCoreApplication.m		\
	WOComponent.m			\
	WOComponent+Sync.m		\
	WOComponentDefinition.m		\
	WOComponentFault.m		\
	WOContext.m			\
	WOElement.m			\
	WOMessage.m			\
	WORequest.m			\
	WOResourceManager.m		\
	WOResponse.m			\
	WORunLoop.m			\
	WOSession.m			\
	WOSessionStore.m		\
	WOStatisticsStore.m		\
	_WOStringTable.m		\
        WOElementID.m			\

libNGObjWeb_OBJC_FILES = \
	$(NGObjWebCore_OBJC_FILES)	\
	NGHttp+WO.m			\
	NGObjWeb.m 			\
	OWViewRequestHandler.m		\
	OWResourceManager.m		\
	UnixSignalHandler.m		\
	WEClientCapabilities.m		\
	WOAdaptor.m			\
	WOApplicationMain.m		\
	WOChildComponentReference.m	\
	WOComponentRequestHandler.m	\
	WOCookie.m			\
	WOCoreApplication+Bundle.m	\
	WODirectAction.m		\
	WODirectActionRequestHandler.m	\
	WODisplayGroup.m		\
	WODynamicElement.m		\
	WOFileSessionStore.m		\
	WOHTTPConnection.m		\
	WOHTTPURLHandle.m		\
	WOMailDelivery.m		\
	WOMessage+XML.m			\
	WOMessage+Validation.m		\
	WOPageRequestHandler.m		\
	WOProxyRequestHandler.m		\
	WORequestHandler.m		\
	WOResourceRequestHandler.m	\
	WOServerSessionStore.m		\
	WOSimpleHTTPParser.m		\
	WOStats.m			\
	NSString+JavaScriptEscaping.m	\

ifeq ($(FOUNDATION_LIB),apple)
libNGObjWeb_OBJC_FILES += WOWatchDogApplicationMainOSX.m
else
libNGObjWeb_OBJC_FILES += WOWatchDogApplicationMain.m
endif

ifeq ($(FOUNDATION_LIB),fd)
NGObjWebCore_OBJC_FILES += WOServerDefaults.m
endif


# framework support

NGObjWeb_PCH_FILE         = $(libNGObjWeb_PCH_FILE)
NGObjWeb_HEADER_FILES_DIR = NGObjWeb
NGObjWeb_HEADER_FILES     = $(libNGObjWeb_HEADER_FILES)
NGObjWeb_OBJC_FILES       = $(libNGObjWeb_OBJC_FILES)
NGObjWeb_SUBPROJECTS      = $(libNGObjWeb_SUBPROJECTS)
NGObjWeb_RESOURCE_FILES   = $(libNGObjWeb_RESOURCES)

# ----- SoCore product for SOPE core registrations

BUNDLE_NAME      = SoCore
BUNDLE_EXTENSION = .sxp
BUNDLE_INSTALL_DIR = $(SOPE_PRODUCTS)/

SoCore_PCH_FILE        = common.h
SoCore_OBJC_FILES      = SoCoreProduct.m
SoCore_RESOURCE_FILES  = SoObjects/product.plist Version
SoCore_PRINCIPAL_CLASS = SoCoreProduct


# ----- NGObjWeb tools

TOOL_NAME = wod

wod_PCH_FILE    += common.h
wod_OBJC_FILES  += wod.m $(NGObjWebCore_OBJC_FILES)
ifeq ($(FOUNDATION_LIB),gnu)
wod_OBJC_FILES  += UnixSignalHandler.m
endif
wod_SUBPROJECTS = Templates Associations


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
include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
