# GNUstep makefile

include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = BasicAuthSn

BasicAuthSn_OBJC_FILES = \
	Application.m		\
	Main.m			\
	NSString+BasicAuth.m	\

BasicAuthSn_COMPONENTS += Main.wo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
