# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = iCalPortal

iCalPortal_OBJC_FILES += \
	iCalPortal.m			\
	iCalPortalDatabase.m		\
	iCalPortalUser.m		\
	iCalPortalCalendar.m		\
	DirectAction.m			\
	\
	iCalPortalPage.m		\
	\
	iCalView.m			\
	iCalDayView.m			\
	iCalWeekView.m			\

# this is a bit of a hack, because our gstep-make version cannot properly
# copy resources of a subproject
iCalPortal_RESOURCE_FILES += Pages/*.wox

iCalPortal_SUBPROJECTS = WebDAV Pages

iCalPortal_LANGUAGES = English German
iCalPortal_LOCALIZED_RESOURCE_FILES = main.strings

include icons.make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
