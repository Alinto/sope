# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
include ./Version

LIBRARY_NAME = libSxComponents
TOOL_NAME = sxc_ls sxc_call

libSxComponents_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libSxComponents_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libSxComponents_HEADER_FILES_DIR         = .
libSxComponents_HEADER_FILES_INSTALL_DIR = /SxComponents
FHS_HEADER_FILES_INSTALL_DIR = $(libSxComponents_HEADER_FILES_INSTALL_DIR)

libSxComponents_HEADER_FILES =  	\
	SxComponents.h			\
	SxComponent.h			\
	SxComponentRegistry.h		\
	SxXmlRpcComponent.h		\
        SxComponentInvocation.h 	\
	SxComponentMethodSignature.h 	\
	SxBasicAuthCredentials.h	\
	SxComponentException.h		\

libSxComponents_OBJC_FILES =    	\
	SxComponent.m			\
	SxComponentRegistry.m		\
        SxComponentInvocation.m 	\
	SxComponentMethodSignature.m	\
	\
	SxXmlRpcRegBackend.m		\
	SxXmlRpcComponent.m		\
	SxXmlRpcInvocation.m		\
	SxBasicAuthCredentials.m	\
	SxComponentException.m		\
	NSObject+SxXmlRpcValue.m	\

sxc_ls_OBJC_FILES   = sxc_ls.m
sxc_call_OBJC_FILES = sxc_call.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
include fhs.make
