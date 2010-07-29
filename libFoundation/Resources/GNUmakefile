# GNUmakefile
#
# Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
# All rights reserved.
#
# Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
#
# This file is part of libFoundation.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies and that both that
# copyright notice and this permission notice appear in supporting
# documentation.
#
# We disclaim all warranties with regard to this software, including all
# implied warranties of merchantability and fitness, in no event shall
# we be liable for any special, indirect or consequential damages or any
# damages whatsoever resulting from loss of use, data or profits, whether in
# an action of contract, negligence or other tortious action, arising out of
# or in connection with the use or performance of this software.

-include ../gsfix.make

ifeq ($(GNUSTEP_MAKEFILES),)

$(warning ERROR: Your $(GNUSTEP_MAKEFILES) environment variable is empty !)
$(error Please try again after running ". $(GNUSTEP_MAKEFILES)/GNUstep.sh")

else

TOP	= ..

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

-include $(GNUSTEP_MAKEFILES)/common.make
-include $(TOP)/Foundation/$(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)/$(OBJC_RUNTIME)/config.mak
-include $(TOP)/config.mak

CHARSETS = alphanumericCharacterSet.bitmap controlCharacterSet.bitmap \
	decimalDigitCharacterSet.bitmap decomposableCharacterSet.bitmap \
	emptyCharacterSet.bitmap illegalCharacterSet.bitmap \
	letterCharacterSet.bitmap lowercaseLetterCharacterSet.bitmap \
	nonBaseCharacterSet.bitmap uppercaseLetterCharacterSet.bitmap \
	whitespaceAndNewlineCharacterSet.bitmap whitespaceCharacterSet.bitmap \
	punctuationCharacterSet.bitmap

TIMEZONES = CET CST6CDT EET EST EST5EDT GB-Eire GMT GMT+1 GMT+10 \
	GMT+11 GMT+12 GMT+13 GMT+2 GMT+3 GMT+4 GMT+5 GMT+6 GMT+7 GMT+8 GMT+9 \
	GMT-1 GMT-10 GMT-11 GMT-12 GMT-2 GMT-3 GMT-4 GMT-5 GMT-6 GMT-7 GMT-8 \
	GMT-9 Greenwich Singapore Iceland Japan MET SGT MST MST7MDT NZ Poland \
	PST8PDT UCT UTC Universal HST W-SU WET Turkey RegionsDictionary \
	GMT+0_30 GMT+10_30 GMT+11_30 GMT+1_30 GMT+2_30 GMT+3_30 GMT+4_30 \
	GMT+5_30 GMT+6_30 GMT+7_30 GMT+8_30 GMT+9_30 GMT-0_30 GMT-10_30 \
	GMT-11_30 GMT-1_30 GMT-2_30 GMT-3_30 GMT-4_30 GMT-5_30 GMT-6_30 \
	GMT-7_30 GMT-8_30 GMT-9_30 GMT+14 CLST SAST

TIMEZONE_DIRS = Australia Canada SystemV US Europe Asia

Australia_ZONES = North NSW Queensland South Victoria West Tasmania
Canada_ZONES = Atlantic Central East-Saskatchewan Eastern Mountain \
	Newfoundland Pacific Yukon
SystemV_ZONES = AST4 AST4ADT CST6 CST6CDT EST5 EST5EDT HST10 MST7 MST7MDT \
	PST8 PST8PDT YST9 YST9YDT
US_ZONES = Arizona Central Eastern Hawaii Mountain Pacific Yukon Pacific-New \
	East-Indiana
EUROPE_ZONES = Berlin Paris Brussels

DEFAULTS = $(wildcard Defaults/*.plist)

all clean distclean realclean check check-all:

ifeq ($(FHS_INSTALL_ROOT),)
INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Libraries/Resources/libFoundation
else
INSTALL_DIR = $(FHS_INSTALL_ROOT)/share/libFoundation
endif

install:
	(PATH=..:$$PATH; export PATH; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/CharacterSets; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/Defaults; \
	for f in $(TIMEZONES); do \
	    $(INSTALL_DATA) $(addprefix TimeZoneInfo/, $$f) \
	        $(INSTALL_DIR)/TimeZoneInfo; \
	done; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/Australia; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/Canada; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/SystemV; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/US; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/Europe; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/Africa; \
	$(TOP)/mkinstalldirs $(INSTALL_DIR)/TimeZoneInfo/Asia; \
	for f in $(Australia_ZONES); do \
	    $(INSTALL_DATA) \
	      $(addprefix TimeZoneInfo/Australia/, $$f) \
	      $(INSTALL_DIR)/TimeZoneInfo/Australia; \
	done; \
	for f in $(Canada_ZONES); do \
	    $(INSTALL_DATA) \
	        $(addprefix TimeZoneInfo/Canada/, $$f) \
	    $(INSTALL_DIR)/TimeZoneInfo/Canada; \
	done; \
	for f in $(SystemV_ZONES); do \
	$(INSTALL_DATA) \
	    $(addprefix TimeZoneInfo/SystemV/, $$f) \
	    $(INSTALL_DIR)/TimeZoneInfo/SystemV; \
	done; \
	for f in $(US_ZONES); do \
	    $(INSTALL_DATA) \
	        $(addprefix TimeZoneInfo/US/, $$f) \
	    $(INSTALL_DIR)/TimeZoneInfo/US; \
	done; \
	for f in $(EUROPE_ZONES); do \
	    $(INSTALL_DATA) \
	        $(addprefix TimeZoneInfo/Europe/, $$f) \
	    $(INSTALL_DIR)/TimeZoneInfo/Europe; \
	done; \
	for f in $(CHARSETS); do \
	    $(INSTALL_DATA) $(addprefix CharacterSets/, $$f) \
	        $(INSTALL_DIR)/CharacterSets; \
	done; \
	for f in $(DEFAULTS); do \
	    if [ ! -f $(INSTALL_DIR)/$$f ]; then \
	      $(INSTALL_DATA) $$f $(INSTALL_DIR)/$$f; \
            fi;\
	done)

uninstall:
	rm -rf $(addprefix $(INSTALL_DIR)/, \
		    CharacterSets TimeZoneInfo  Defaults)

endif
