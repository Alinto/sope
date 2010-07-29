#
#  StructuredText.subproj makefile for StructuredText.
#  
#  Author: Mirko Viviani <mirko@objectlab.org>
#
#  Date: 24 November 2003
#

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = Model

Model_PCH_FILE = common.h

Model_OBJC_FILES = \
	StructuredTextDocument.m	\
	StructuredTextBodyElement.m	\
	StructuredTextParagraph.m	\
	StructuredTextListItem.m	\
	StructuredTextList.m		\
	StructuredTextLiteralBlock.m	\
	StructuredTextHeader.m

ADDITIONAL_INCLUDE_DIRS += \
	-I. -I.. -I../ExtraSTX

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
