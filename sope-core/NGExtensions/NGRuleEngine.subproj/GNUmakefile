# GNUstep makefile

include ../../../config.make
include ../../common.make

SUBPROJECT_NAME = NGRuleEngine

NGRuleEngine_PCH_FILE = common.h

NGRuleEngine_OBJC_FILES = \
	NGRule.m		\
	NGRuleAssignment.m	\
	NGRuleContext.m		\
	NGRuleModel.m		\
	NGRuleParser.m		\

ADDITIONAL_INCLUDE_DIRS += -I. -I.. -I../NGExtensions/ -I../..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
