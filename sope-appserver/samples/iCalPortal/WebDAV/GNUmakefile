# GNUstep makefile

-include ../../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = DAV

DAV_OBJC_FILES = \
	iCalRequestHandler.m		\
	iCalAction.m			\
	\
	iCalPublishAction.m		\
	iCalGetAction.m			\
	iCalDeleteAction.m		\
	iCalOptionsAction.m		\
	iCalLockAction.m		\

ADDITIONAL_INCLUDE_DIRS += -I. -I..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
