# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = HelloForm

HelloForm_OBJC_FILES += HelloForm.m Main.m
HelloForm_COMPONENTS += Main.wo

HelloForm_WEBSERVER_RESOURCE_FILES += Main.css

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
