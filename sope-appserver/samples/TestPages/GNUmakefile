# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = TestPages

TestPages_OBJC_FILES += \
	TestPages.m	\
	Main.m		\
	TwoForms.m	\
	FormDisplay.m	\

TestPages_COMPONENTS += \
	Main.wo		\
	TwoForms.wo	\
	FormDisplay.wo	\

# for testing resources
TestPages_RESOURCE_FILES  += $(TestPages_OBJC_FILES)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
