# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME   = libWEPrototype

BUNDLE_NAME      = WEPrototype
BUNDLE_EXTENSION = .wox
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/WOxElemBuilders-$(MAJOR_VERSION).$(MINOR_VERSION)/
else
FRAMEWORK_NAME = WEPrototype
endif

FHS_MANPAGES += doc/*.3

libWEPrototype_PCH_FILE = common.h
WEPrototype_PCH_FILE = common.h
libWEPrototype_HEADER_FILES_DIR         = .
libWEPrototype_HEADER_FILES_INSTALL_DIR = /WEPrototype

libWEPrototype_HEADER_FILES =

libWEPrototype_OBJC_FILES = \
	WEPrototypeScriptAction.m	\
	WEPrototypeScript.m		\
	WELiveLink.m			\
	WEPrototypeElemBuilder.m	\

WEPrototype_OBJC_FILES      = WEPrototypeBundle.m
WEPrototype_PRINCIPAL_CLASS = WEPrototypeBundle

# framework support

ifeq ($(frameworks),yes)
WEPrototype_HEADER_FILES_DIR = WEPrototype
WEPrototype_HEADER_FILES = $(libWEPrototype_HEADER_FILES)
WEPrototype_OBJC_FILES   = $(libWEPrototype_OBJC_FILES)
WEPrototype_SUBPROJECTS  = $(libWEPrototype_SUBPROJECTS)
endif


# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
-include fhs.make
