# GNUstep makefile

-include ../../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = Pages

Pages_OBJC_FILES = \
	iCalPortalBaseFrame.m		\
	iCalPortalBox.m			\
	iCalPortalCalTabs.m		\
	iCalPortalDayOverview.m		\
	iCalPortalFeedbackPage.m	\
	iCalPortalFrame.m		\
	iCalPortalHomePage.m		\
	iCalPortalLeftMenu.m		\
	iCalPortalLicensePage.m		\
	iCalPortalMonthView.m		\
	iCalPortalProfilePage.m		\
	iCalPortalRegistrationPage.m	\
	iCalPortalRightMenu.m		\
	iCalPortalToDoView.m		\
	iCalPortalWeekOverview.m	\
	iCalPortalWelcomePage.m		\

ADDITIONAL_INCLUDE_DIRS += -I. -I..

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
