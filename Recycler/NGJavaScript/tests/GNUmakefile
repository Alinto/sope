# $Id$

include ../../common.make

SUBPROJECT_NAME = JSTests

JSTests_OBJC_FILES = \
	Blah.m			\
	Combined.m		\
	MyNum.m			\
	\
	JSTest.m		\
	JSArchivingTests.m	\
	JSBridgeTests.m		\

ADDITIONAL_CPPFLAGS += -DXP_UNIX=1

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
