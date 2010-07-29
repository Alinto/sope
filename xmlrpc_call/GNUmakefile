# GNUstep makefile

-include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

TOOL_NAME = xmlrpc_call

xmlrpc_call_PCH_FILE = common.h

xmlrpc_call_OBJC_FILES += \
	xmlrpc_call.m		\
	XmlRpcClientTool.m	\
	NSObject+Printing.m	\
	HandleCredentialsClient.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make

macosx-pkg ::
	# do not build a pkg just for this tool

