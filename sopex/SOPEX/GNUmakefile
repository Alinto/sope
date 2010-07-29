# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

FRAMEWORK_NAME = SOPEX

SOPEX_PCH_FILE = common.h

SOPEX_HEADER_FILES += \
	SOPEX.h				\
	SOPEXAppController.h		\
	SOPEXAuthPanel.h		\
	SOPEXBrowserController.h	\
	SOPEXBrowserWindow.h		\
	SOPEXConsole.h			\
	SOPEXConstants.h		\
	SOPEXContentValidator.h		\
	SOPEXDocument.h			\
	SOPEXMain.h			\
	SOPEXRangeUtilities.h		\
	SOPEXSheetRunner.h		\
	SOPEXStatisticsController.h	\
	SOPEXTextView.h			\
	SOPEXToolbarController.h	\
	SOPEXWODocument.h		\
	SOPEXWOXDocument.h		\
	SOPEXWebConnection.h		\
	SOPEXWebMetaParser.h		\

SOPEX_OBJC_FILES += \
	SOPEXAppController.m		\
	SOPEXAuthPanel.m		\
	SOPEXBrowserController.m	\
	SOPEXBrowserWindow.m		\
	SOPEXConsole.m			\
	SOPEXConsoleAppender.m		\
	SOPEXConsoleEventFormatter.m	\
	SOPEXConstants.m		\
	SOPEXContentValidator.m		\
	SOPEXDocument.m			\
	SOPEXMain.m			\
	SOPEXRangeUtilities.m		\
	SOPEXSheetRunner.m		\
	SOPEXStatisticsController.m	\
	SOPEXTextView.m			\
	SOPEXToolbarController.m	\
	SOPEXWODocument.m		\
	SOPEXWOXDocument.m		\
	SOPEXWebConnection.m		\
	SOPEXWebMetaParser.m		\
	\
	WebView+Ext.m			\
	NSBundle+Ext.m			\
	NSString+Ext.m			\

SOPEX_LANGUAGES += \
	English

SOPEX_LOCALIZED_RESOURCE_FILES += \
	InfoPlist.strings		\
	Localizable.strings		\
	SOPEXBrowserController.nib	\
	SOPEXConsole.nib		\
	SOPEXConsole.toolbar		\
	SOPEXStatisticsNatLang.plist	\
	SOPEXStats.nib			\
	SOPEXWebUI.toolbar

SOPEX_RESOURCE_FILES += \
	Clean.tiff	\
	Info.plist	\
	Lori.icns	\
	Reload.tiff	\
	version.plist

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
