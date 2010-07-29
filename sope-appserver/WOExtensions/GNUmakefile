# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME     = libWOExtensions
BUNDLE_NAME      = WOExtensions
BUNDLE_EXTENSION = .wox
BUNDLE_INSTALL_DIR = $(SOPE_WOXBUILDERS)/

else
FRAMEWORK_NAME = WOExtensions
endif


FHS_MANPAGES += doc/*.3

libWOExtensions_PCH_FILE = common.h
WOExtensions_PCH_FILE = common.h

libWOExtensions_HEADER_FILES_DIR	 = .
libWOExtensions_HEADER_FILES_INSTALL_DIR = /WOExtensions

libWOExtensions_HEADER_FILES = \
	WOExtensions.h			\
	WORedirect.h			\

libWOExtensions_OBJC_FILES = \
	WOxExtElemBuilder.m		\
	compat.m		        \
	WOKeyValueConditional.m	        \
	WORedirect.m		        \
	WOTabPanel.m		        \
	WOTable.m		        \
	JSAlertPanel.m		        \
	JSConfirmPanel.m	        \
	JSImageFlyover.m	        \
	JSTextFlyover.m		        \
	JSValidatedField.m	        \
	JSModalWindow.m                 \
	WOCollapsibleComponentContent.m \
	WODictionaryRepetition.m        \
	WOThresholdColoredNumber.m      \
	WORadioButtonMatrix.m           \
	WOCheckBoxMatrix.m              \



ifeq ($(frameworks),yes)
# framework support

WOExtensions_HEADER_FILES = $(libWOExtensions_HEADER_FILES)

WOExtensions_OBJC_FILES   = \
	$(libWOExtensions_OBJC_FILES) \
	WOExtensionsBuilderModule.m

WOExtensions_SUBPROJECTS  = $(libWOExtensions_SUBPROJECTS)
WOExtensions_PRINCIPAL_CLASS = WOExtensionsBuilderModule
WOExtensions_RESOURCE_FILES  += bundle-info.plist Version *.api

else
# bundle
WOExtensions_OBJC_FILES      += WOExtensionsBuilderModule.m
WOExtensions_PRINCIPAL_CLASS = WOExtensionsBuilderModule
endif

# building

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
