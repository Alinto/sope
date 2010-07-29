# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
include ./Version

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)

LIBRARY_NAME  = libNGObjDOM
RESOURCES_DIR = $(GNUSTEP_LOCAL_ROOT)/Libraries/Resources/NGObjDOM

libNGObjDOM_SUBPROJECTS = Dynamic.subproj

SUBPROJECTS = XUL.subproj XHTML.subproj

libNGObjDOM_HEADER_FILES_DIR         = .
libNGObjDOM_HEADER_FILES_INSTALL_DIR = /NGObjDOM
FHS_HEADER_FILES_INSTALL_DIR = $(libNGObjDOM_HEADER_FILES_INSTALL_DIR)
libNGObjDOM_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGObjDOM_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGObjDOM_HEADER_FILES = \
	NGObjDOM.h			\
	ODNamespaces.h			\
	ODNodeRenderer.h		\
	ODNodeRendererFactory.h		\
	ODNodeRendererFactorySet.h	\
	ODREmbedComponent.h		\
	ODRGenericTag.h			\
	ODRNodeText.h			\
	ODRWebObject.h			\
	WORenderDOM.h			\
	ODNodeRenderer+attributes.h	\
	WOContext+Cursor.h		\
	\
	ODR_bind_tableview.h	 	\
	ODR_bind_tabview.h		\
	ODR_bind_collapsible.h	 	\
	ODR_bind_viewertitle.h	 	\
	ODR_bind_fieldset.h		\

libNGObjDOM_OBJC_FILES = \
	ODNodeRenderer.m		\
	ODNodeRendererFactory.m		\
	ODNodeRendererFactorySet.m	\
	ODREmbedComponent.m		\
	ODRGenericTag.m			\
	ODRNodeText.m			\
	ODRWebObject.m			\
	ODWONodeRenderFactory.m		\
	WORenderDOM.m			\
	ODNodeRenderer+attributes.m	\

# bundle

BUNDLE_NAME        = NGObjDOM
BUNDLE_EXTENSION   = .odr
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/Bundles

NGObjDOM_OBJC_FILES  = NGObjDOMModule.m


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
include fhs.make
