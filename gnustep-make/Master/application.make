#
#   application.make
#
#   Master makefile rules to build GNUstep-based applications.
#
#   Copyright (C) 1997, 2001, 2002 Free Software Foundation, Inc.
#
#   Author:  Nicola Pero <nicola@brainstorm.co.uk>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
#   Based on the original version by Scott Christley.
#
#   This file is part of the GNUstep Makefile Package.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#   
#   You should have received a copy of the GNU General Public
#   License along with this library; see the file COPYING.LIB.
#   If not, write to the Free Software Foundation,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

APP_NAME := $(strip $(APP_NAME))

internal-all:: $(APP_NAME:=.all.app.variables)

internal-install:: $(APP_NAME:=.install.app.variables)

internal-uninstall:: $(APP_NAME:=.uninstall.app.variables)

# Compute them manually to avoid having to do an Instance make
# invocation just to remove them.
_PSWRAP_C_FILES = $(foreach app,$(APP_NAME),$($(app)_PSWRAP_FILES:.psw=.c))
_PSWRAP_H_FILES = $(foreach app,$(APP_NAME),$($(app)_PSWRAP_FILES:.psw=.h))
# The following intricate code computes the list of xxxInfo.plist files
# for all applications xxx which have xxx_PREPROCESS_INFO_PLIST=yes.
_PLIST_INFO_FILES = $(addsuffix Info.plist,$(foreach app,$(APP_NAME),$(patsubst yes,$(app),$($(app)_PREPROCESS_INFO_PLIST))))

internal-clean::
ifeq ($(GNUSTEP_FLATTENED),)
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES) \
	  $(_PLIST_INFO_FILES) *.$(APP_EXTENSION)/$(GNUSTEP_TARGET_LDIR))
else
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES) \
	  $(_PLIST_INFO_FILES) *.$(APP_EXTENSION))
endif

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj *.app *.debug *.profile)

# The following make trick extracts all tools in APP_NAME for which
# the xxx_SUBPROJECTS variable is set to something non-empty.
# For those apps (and only for them), we need to run 'clean' and
# 'distclean' in subprojects too.
#
# Please note that newer GNU make has a $(if condition,then,else)
# function, which would be so handy here!  But unfortunately it's not
# available in older GNU makes, so we must not use it.  This trick
# works around this problem.

APPS_WITH_SUBPROJECTS = $(strip $(foreach app,$(APP_NAME),$(patsubst %,$(app),$($(app)_SUBPROJECTS))))
ifneq ($(APPS_WITH_SUBPROJECTS),)
internal-clean:: $(APPS_WITH_SUBPROJECTS:=.clean.app.subprojects)
internal-distclean:: $(APPS_WITH_SUBPROJECTS:=.distclean.app.subprojects)
endif

internal-strings:: $(APP_NAME:=.strings.app.variables)

# FIXME - GNUSTEP_BUILD_DIR here.  Btw should we remove this or
# provide a better more general way of doing it ?
$(APP_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory $@.all.app.variables
