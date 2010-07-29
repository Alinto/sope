# $Id: GNUmakefile,v 1.1 2004/06/08 11:15:59 helge Exp $

include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = libApacheAPI libApHelper
BUNDLE_NAME  = ApTest
MODULE_NAME  = gsbundle

libApacheAPI_OBJC_FILES = \
	ApacheCmdParms.m		\
	ApacheConnection.m		\
	ApacheObject.m			\
	ApacheRequest.m			\
	ApacheResourcePool.m		\
	ApacheServer.m			\
	ApacheTable.m			\
	ApacheModule.m			\
	ApModuleBaseClass.m		\
	ApModuleBaseClass+Callbacks.m	\
	ApModuleBaseClass+Handler.m	\
	ApModuleBaseClass+Cmds.m	\

libApHelper_OBJC_FILES = \
	GSBundleModule.m	\

gsbundle_OBJC_FILES = \
	mod_gsbundle.m		\

ApTest_PRINCIPAL_CLASS = ApTest
ApTest_OBJC_FILES = \
	ApTest.m			\
	ApTest_module_structure.m	\

libApHelper_LIBRARIES_DEPEND_UPON += \
	-lApacheAPI	\
	-lFoundation	\
	-lobjc		\
	-lpthread

ADDITIONAL_LIB_DIRS  += -L./$(GNUSTEP_OBJ_DIR)
ApTest_BUNDLE_LIBS   += -lApacheAPI

gsbundle_TOOL_LIBS   += -lpthread -ldl

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/apache.make
include $(GNUSTEP_MAKEFILES)/bundle.make

before-ApTest-all:: 
	genApacheModule.sh ApTest ApTest_module_structure.m
