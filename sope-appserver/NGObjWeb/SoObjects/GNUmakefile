# GNUstep makefile

include ../subdirs.make
include ../../../config.make

SUBPROJECT_NAME = SoObjects

SoObjects_PCH_FILE = common.h
SoObjects_HEADER_FILES_DIR         = .
SoObjects_HEADER_FILES_INSTALL_DIR = /NGObjWeb

SoObjects_HEADER_FILES = \
	SoObjects.h			\
	NSException+HTTP.h		\
	SoClass.h			\
	SoClassRegistry.h		\
	SoClassSecurityInfo.h		\
	SoDefaultRenderer.h		\
	SoHTTPAuthenticator.h		\
	SoObjCClass.h			\
	SoObject.h			\
	SoObjectMethodDispatcher.h	\
	SoObjectRequestHandler.h	\
	SoPageInvocation.h		\
	SoActionInvocation.h		\
	SoPermissions.h			\
	SoProduct.h			\
	SoProductClassInfo.h		\
	SoProductRegistry.h		\
	SoProductResourceManager.h	\
	SoSecurityManager.h		\
	SoSelectorInvocation.h		\
	SoUser.h			\
	WOContext+SoObjects.h		\
	WORequest+So.h			\
	SoControlPanel.h		\
	SoApplication.h			\
	SoLookupAssociation.h		\
	SoTemplateRenderer.h		\
	SoSubContext.h			\
	SoSecurityException.h		\
	SoComponent.h			\
	SoProductLoader.h		\
	SoCookieAuthenticator.h		\

SoObjects_OBJC_FILES = \
	NSException+HTTP.m		\
	SoApplication.m			\
	SoClass.m			\
	SoClassRegistry.m		\
	SoClassSecurityInfo.m		\
	SoControlPanel.m		\
	SoDefaultRenderer.m		\
	SoHTTPAuthenticator.m		\
	SoObjCClass.m			\
	SoObject+Traversal.m		\
	SoObject.m			\
	SoObjectMethodDispatcher.m	\
	SoObjectRequestHandler.m	\
	SoObjectSOAPDispatcher.m	\
	SoPageInvocation.m		\
	SoActionInvocation.m		\
	SoPermissions.m			\
	SoProduct.m			\
	SoProductClassInfo.m		\
	SoProductRegistry.m		\
	SoProductResourceManager.m	\
	SoSecurityManager.m		\
	SoSelectorInvocation.m		\
	SoUser.m			\
	SoLookupAssociation.m		\
	WOContext+SoObjects.m		\
	WODirectAction+SoObjects.m	\
	WOComponent+SoObjects.m		\
	WODirectActionRequestHandler+SoObjects.m\
	WORequest+So.m			\
	SoTemplateRenderer.m		\
	SoSubContext.m			\
	SoSecurityException.m		\
	SoComponent.m			\
	SoProductLoader.m		\
	SoCookieAuthenticator.m		\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
