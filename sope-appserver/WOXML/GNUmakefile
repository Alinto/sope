# GNUstep makefile

-include ../../config.make
include ../common.make
include ../Version
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libWOXML
else
FRAMEWORK_NAME = WOXML
endif


libWOXML_PCH_FILE = common.h
libWOXML_HEADER_FILES_DIR         = .
libWOXML_HEADER_FILES_INSTALL_DIR = /WOXML


libWOXML_HEADER_FILES += \
	WOXML.h			\
	WOXMLDecoder.h		\
	WOXMLMappingModel.h	\

libWOXML_OBJC_FILES += \
	WOXMLDecoder.m		\
	\
	WOXMLMapDecoder.m	\
	WOXMLMappingEntity.m	\
	WOXMLMappingModel.m	\
	WOXMLMappingProperty.m	\
	WOXMLSaxModelHandler.m	\

# framework support

WOXML_PCH_FILE     = $(libWOXML_PCH_FILE)
WOXML_HEADER_FILES = $(libWOXML_HEADER_FILES)
WOXML_OBJC_FILES   = $(libWOXML_OBJC_FILES)
WOXML_SUBPROJECTS  = $(libWOXML_SUBPROJECTS)


# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
-include fhs.make
