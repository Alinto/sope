# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = CoreDataBlog

CoreDataBlog_OBJC_FILES += \
	WOCoreDataApplication.m		\
	WOSession+CoreData.m		\
	\
	CoreDataBlog.m	\
	Session.m	\
	Main.m		\
	\
	MonthPage.m	\
	RSS10.m		\

CoreDataBlog_COMPONENTS += \
	Main.wo		\
	MonthPage.wo	\
	RSS10.wo

CoreDataBlog_COREDATA_MODELS += \
	BlogDemo_DataModel.xcdatamodel

CoreDataBlog_RESOURCE_FILES += Defaults.plist


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
