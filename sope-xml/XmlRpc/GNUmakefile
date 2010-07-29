# GNUstep makefile

include ../../config.make
include ../common.make

ifneq ($(frameworks),yes)
LIBRARY_NAME   = libXmlRpc
else
FRAMEWORK_NAME = XmlRpc
XmlRpc_RESOURCE_FILES += Version
endif

libXmlRpc_PCH_FILE = common.h
XmlRpc_PCH_FILE = common.h

libXmlRpc_HEADER_FILES = \
	XmlRpc.h			\
	NSObject+XmlRpc.h		\
	XmlRpcCoder.h			\
	XmlRpcMethodCall.h		\
	XmlRpcMethodResponse.h		\

libXmlRpc_OBJC_FILES = \
	XmlRpcEncoder.m			\
	XmlRpcDecoder.m			\
	XmlRpcMethodCall.m		\
	XmlRpcMethodResponse.m		\
	XmlRpcSaxHandler.m		\
	XmlRpcValue.m			\
	NSMutableString+XmlRpcDecoder.m	\
	\
	NSArray+XmlRpcCoding.m		\
	NSData+XmlRpcCoding.m		\
	NSDate+XmlRpcCoding.m		\
	NSDictionary+XmlRpcCoding.m	\
	NSException+XmlRpcCoding.m	\
	NSHost+XmlRpcCoding.m		\
	NSNotification+XmlRpcCoding.m	\
	NSNumber+XmlRpcCoding.m		\
	NSObject+XmlRpc.m		\
	NSString+XmlRpcCoding.m		\
	NSURL+XmlRpcCoding.m		\


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
