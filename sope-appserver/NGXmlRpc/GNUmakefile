# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGXmlRpc
else
FRAMEWORK_NAME = NGXmlRpc
endif

libNGXmlRpc_PCH_FILE = common.h
libNGXmlRpc_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGXmlRpc_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGXmlRpc_HEADER_FILES_DIR         = .
libNGXmlRpc_HEADER_FILES_INSTALL_DIR = /NGXmlRpc

libNGXmlRpc_HEADER_FILES = \
	NGAsyncResultProxy.h			\
	NGXmlRpc.h				\
	NGXmlRpcAction.h			\
	NGXmlRpcClient.h			\
	NGXmlRpcInvocation.h			\
	NGXmlRpcMethodSignature.h		\
	NGXmlRpcRequestHandler.h		\
	NSObject+Reflection.h			\
	WODirectAction+XmlRpc.h			\
	WODirectAction+XmlRpcIntrospection.h	\
	XmlRpcMethodCall+WO.h			\
	XmlRpcMethodResponse+WO.h		\

libNGXmlRpc_OBJC_FILES = \
	EOFetchSpecification+XmlRpcCoding.m	\
	EOKeyGlobalID+XmlRpcCoding.m		\
	EONull+XmlRpcCoding.m			\
	EOQualifier+XmlRpcCoding.m		\
	EOSortOrdering+XmlRpcCoding.m		\
	NGAsyncResultProxy.m			\
	NGXmlRpcAction.m			\
	NGXmlRpcClient.m			\
	NGXmlRpcInvocation.m			\
	NGXmlRpcMethodSignature.m		\
	NGXmlRpcRequestHandler.m		\
	NSObject+Reflection.m			\
	WODirectAction+XmlRpc.m			\
	WODirectAction+XmlRpcIntrospection.m	\
	WOMessage+XmlRpcCoding.m		\
	WORequest+XmlRpcCoding.m		\
	WOResponse+XmlRpcCoding.m		\
	XmlRpcMethodCall+WO.m			\
	XmlRpcMethodResponse+WO.m		\
	NGXmlRpcAction+Registry.m		\


# framework support

NGXmlRpc_PCH_FILE     = $(libNGXmlRpc_PCH_FILE)
NGXmlRpc_HEADER_FILES = $(libNGXmlRpc_HEADER_FILES)
NGXmlRpc_OBJC_FILES   = $(libNGXmlRpc_OBJC_FILES)


# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make
