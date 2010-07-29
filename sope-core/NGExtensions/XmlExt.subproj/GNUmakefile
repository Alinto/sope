# GNUstep makefile

include ../../../config.make
include ../../common.make

SUBPROJECT_NAME = XmlExt

XmlExt_OBJC_FILES = \
	DOMNode+EOQualifier.m

ADDITIONAL_INCLUDE_DIRS += \
	-I. -I..		\
	-I../NGExtensions/	\
	-I../../../sope-xml/	\
	-I../..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
