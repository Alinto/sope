# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = Associations

Associations_PCH_FILE = common.h

Associations_OBJC_FILES = \
	WOAssociation.m			\
	WOValueAssociation.m		\
	WOKeyPathAssociation.m		\
	WOKeyPathAssociationSystemKVC.m	\
	WOScriptAssociation.m		\
	WOResourceURLAssociation.m	\
	WOLabelAssociation.m		\
	\
	NSUserDefaults+KVC.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
