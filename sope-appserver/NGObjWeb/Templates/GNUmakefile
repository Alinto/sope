# GNUmakefile makefile

include ../subdirs.make
include ../../../config.make

SUBPROJECT_NAME = Templates

Templates_PCH_FILE = common.h
Templates_HEADER_FILES_DIR         = .
Templates_HEADER_FILES_INSTALL_DIR = /NGObjWeb

Templates_OBJC_FILES =   \
	WOComponentScript.m		\
	WOComponentScriptPart.m		\
	WODParser.m			\
	WOHTMLParser.m			\
	WOSubcomponentInfo.m		\
	WOTemplate.m			\
	WOTemplateBuilder.m		\
	WOWrapperTemplateBuilder.m	\
	WOxComponentElemBuilder.m	\
	WOxTemplateBuilder.m		\
        WOxElemBuilder.m		\
	WOxTagClassElemBuilder.m	\
	WOApplication+Builders.m	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
