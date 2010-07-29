#
#   Master/bundle.make
#
#   Master makefile rules to build GNUstep-based bundles.
#
#   Copyright (C) 1997, 2001 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
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

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

BUNDLE_NAME := $(strip $(BUNDLE_NAME))

internal-all:: $(BUNDLE_NAME:=.all.bundle.variables)

internal-install:: $(BUNDLE_NAME:=.install.bundle.variables)

internal-uninstall:: $(BUNDLE_NAME:=.uninstall.bundle.variables)

_PSWRAP_C_FILES = $(foreach bundle,$(BUNDLE_NAME),$($(bundle)_PSWRAP_FILES:.psw=.c))
_PSWRAP_H_FILES = $(foreach bundle,$(BUNDLE_NAME),$($(bundle)_PSWRAP_FILES:.psw=.h))

internal-clean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES) \
	       $(addsuffix $(BUNDLE_EXTENSION),$(BUNDLE_NAME)))
	rm -rf $(DERIVED_SOURCES_DIR)

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj)

BUNDLES_WITH_SUBPROJECTS = $(strip $(foreach bundle,$(BUNDLE_NAME),$(patsubst %,$(bundle),$($(bundle)_SUBPROJECTS))))

ifneq ($(BUNDLES_WITH_SUBPROJECTS),)
internal-clean:: $(BUNDLES_WITH_SUBPROJECTS:=.clean.bundle.subprojects)
internal-distclean:: $(BUNDLES_WITH_SUBPROJECTS:=.distclean.bundle.subprojects)
endif

internal-strings:: $(BUNDLE_NAME:=.strings.bundle.variables)

$(BUNDLE_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
		$@.all.bundle.variables
