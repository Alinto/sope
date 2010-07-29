# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGiCal
else
FRAMEWORK_NAME = NGiCal
endif


libNGiCal_PCH_FILE = common.h
libNGiCal_HEADER_FILES_DIR         = .
libNGiCal_HEADER_FILES_INSTALL_DIR = /NGiCal
libNGiCal_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGiCal_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGiCal_HEADER_FILES =  		\
	NGiCal.h			\
	iCalAttachment.h		\
	iCalObject.h			\
	iCalEntityObject.h		\
	iCalRepeatableEntityObject.h	\
	iCalCalendar.h			\
	iCalToDo.h			\
	iCalJournal.h			\
	iCalEvent.h			\
	iCalFreeBusy.h			\
	iCalPerson.h			\
	iCalAlarm.h			\
	iCalDuration.h			\
	iCalTrigger.h			\
	iCalDataSource.h		\
	iCalEventChanges.h		\
	iCalRenderer.h			\
	iCalRecurrenceRule.h		\
	iCalRecurrenceCalculator.h	\
					\
	NSCalendarDate+ICal.h		\
	\
	NGVCard.h			\
	NGVCardAddress.h		\
	NGVCardStrArrayValue.h		\
	NGVCardName.h			\
	NGVCardOrg.h			\
	NGVCardPhone.h			\
	NGVCardSaxHandler.h		\
	NGVCardSimpleValue.h		\
	NGVCardValue.h			\

#	IcalResponse.h			\

libNGiCal_OBJC_FILES =    		\
	NSCalendarDate+ICal.m		\
	iCalDateHolder.m		\
	\
	iCalAttachment.m		\
	iCalObject.m			\
	iCalEntityObject.m		\
	iCalRepeatableEntityObject.m	\
	iCalCalendar.m			\
	iCalToDo.m			\
	iCalJournal.m			\
	iCalEvent.m			\
	iCalFreeBusy.m			\
	iCalPerson.m			\
	iCalAlarm.m			\
	iCalDuration.m			\
	iCalTrigger.m			\
	iCalDataSource.m		\
	iCalEventChanges.m		\
	iCalRenderer.m			\
	iCalRecurrenceRule.m		\
	iCalRecurrenceCalculator.m	\
	iCalDailyRecurrenceCalculator.m	\
	iCalWeeklyRecurrenceCalculator.m\
	iCalMonthlyRecurrenceCalculator.m \
	iCalYearlyRecurrenceCalculator.m\
	\
	NGICalSaxHandler.m		\
	\
	NGVCard.m			\
	NGVCardAddress.m		\
	NGVCardStrArrayValue.m		\
	NGVCardName.m			\
	NGVCardOrg.m			\
	NGVCardPhone.m			\
	NGVCardSaxHandler.m		\
	NGVCardSimpleValue.m		\
	NGVCardValue.m			\

#	NSString+ICal.m			\
#	IcalElements.m
#	IcalResponse.m


# framework support

NGiCal_PCH_FILE     = $(libNGiCal_PCH_FILE)
NGiCal_HEADER_FILES = $(libNGiCal_HEADER_FILES)
NGiCal_OBJC_FILES   = $(libNGiCal_OBJC_FILES)
NGiCal_SUBPROJECTS  = $(libNGiCal_SUBPROJECTS)


# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
-include fhs.make
