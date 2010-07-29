#
#   Master/test-application.make
#
#   Copyright (C) 1997, 2001, 2002 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Nicola Pero <nicola@brainstorm.co.uk>
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

TEST_APP_NAME := $(strip $(TEST_APP_NAME))

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

# Building of test applications works as in application.make, except
# you can't install them!

internal-all:: $(TEST_APP_NAME:=.all.test-app.variables)

_PSWRAP_C_FILES = $(foreach app,$(TEST_APP_NAME),$($(app)_PSWRAP_FILES:.psw=.c))
_PSWRAP_H_FILES = $(foreach app,$(TEST_APP_NAME),$($(app)_PSWRAP_FILES:.psw=.h))

internal-clean::
ifeq ($(GNUSTEP_FLATTENED),)
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES) \
	  *.$(APP_EXTENSION)/$(GNUSTEP_TARGET_LDIR))
else
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES) \
	  *.$(APP_EXTENSION))
endif

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj *.app *.debug *.profile)

TEST_APPS_WITH_SUBPROJECTS = $(strip $(foreach test-app,$(TEST_APP_NAME),$(patsubst %,$(test-app),$($(test-app)_SUBPROJECTS))))
ifneq ($(TEST_APPS_WITH_SUBPROJECTS),)
internal-clean:: $(TEST_APPS_WITH_SUBPROJECTS:=.clean.test-app.subprojects)
internal-distclean:: $(TEST_APPS_WITH_SUBPROJECTS:=.distclean.test-app.subprojects)
endif

internal-strings:: $(TEST_APP_NAME:=.strings.test-app.variables)

$(TEST_APP_NAME)::
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
	         $@.all.test-app.variables

internal-install::
	@ echo Skipping installation of test apps...

internal-uninstall::
	@ echo Skipping uninstallation of test apps...
