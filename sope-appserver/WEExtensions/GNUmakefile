# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version


ifneq ($(frameworks),yes)
LIBRARY_NAME   = libWEExtensions

BUNDLE_NAME      = WEExtensions
BUNDLE_EXTENSION = .wox
BUNDLE_INSTALL_DIR = $(SOPE_WOXBUILDERS)/

else
FRAMEWORK_NAME = WEExtensions
endif



FHS_MANPAGES += doc/*.3

libWEExtensions_PCH_FILE = common.h
WEExtensions_PCH_FILE = common.h

libWEExtensions_HEADER_FILES_DIR         = .
libWEExtensions_HEADER_FILES_INSTALL_DIR = /WEExtensions

libWEExtensions_HEADER_FILES = \
	WEContextConditional.h	\
	WEResourceManager.h	\

libWEExtensions_OBJC_FILES =   \
	JSClipboard.m			\
	JSShiftClick.m                  \
	WEBrowser.m                     \
	WECalendarField.m               \
	WECollapsibleComponentContent.m \
	WEComponentValue.m              \
	WEContextConditional.m          \
	WEContextKey.m                  \
	WEDateField.m                   \
	WEDragContainer.m	        \
	WEDropContainer.m	        \
	WEMonthOverview.m               \
	WEPageView.m                    \
	WEPageLink.m			\
	WERichString.m                  \
	WESwitch.m                      \
	WETabItem.m			\
	WETabView.m                     \
	WETableCalcMatrix.m             \
	WETableMatrix.m                 \
	WETableMatrixContent.m          \
	WETableMatrixLabel.m            \
	WETimeField.m                   \
	WETreeView.m                    \
	WETreeHeader.m			\
	WETreeData.m			\
	WETreeMatrixElement.m		\
	WEWeekColumnView.m		\
	WEWeekOverview.m                \
	WExExtElemBuilder.m		\
	WExCalElemBuilder.m		\
	WExDnDElemBuilder.m		\
	WEEpozEditor.m			\
	WEQualifierConditional.m	\
	WERedirect.m			\
	\
	WEResourceManager.m		\
	WEResourceKey.m			\
	WEStringTable.m			\
	WEStringTableManager.m		\
	\
	JSStringTable.m			\

libWEExtensions_SUBPROJECTS += \
	WETableView


ifeq ($(frameworks),yes)
# framework support

WEExtensions_HEADER_FILES = $(libWEExtensions_HEADER_FILES)
WEExtensions_OBJC_FILES   = $(libWEExtensions_OBJC_FILES) WEExtensionsBundle.m
WEExtensions_SUBPROJECTS  = $(libWEExtensions_SUBPROJECTS)
WEExtensions_PRINCIPAL_CLASS = WEExtensionsBundle
WEExtensions_RESOURCE_FILES  += bundle-info.plist Version *.api

else
# bundle

WEExtensions_OBJC_FILES      = WEExtensionsBundle.m
WEExtensions_PRINCIPAL_CLASS = WEExtensionsBundle
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
