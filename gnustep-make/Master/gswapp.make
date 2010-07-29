#
#   Master/gswapp.make
#
#   Master Makefile rules to build GNUstep web based applications.
#
#   Copyright (C) 1997 Free Software Foundation, Inc.
#
#   Author:  Manuel Guesdon <mguesdon@sbuilders.com>
#   Based on application.make by Ovidiu Predescu <ovidiu@net-community.com>
#   Based on gswapp.make by Helge Hess, MDlink online service center GmbH.
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

# Determine the application directory extension
ifeq ($(profile), yes)
  GSWAPP_EXTENSION=profile
else
  ifeq ($(debug), yes)
    GSWAPP_EXTENSION=debug
  else
    GSWAPP_EXTENSION=gswa
  endif
endif

GSWAPP_NAME := $(strip $(GSWAPP_NAME))

internal-all:: $(GSWAPP_NAME:=.all.gswapp.variables)

internal-install:: $(GSWAPP_NAME:=.install.gswapp.variables)

internal-uninstall:: $(GSWAPP_NAME:=.uninstall.gswapp.variables)

internal-clean::
ifeq ($(GNUSTEP_FLATTENED),)
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) \
	  *.$(GSWAPP_EXTENSION)/$(GNUSTEP_TARGET_LDIR))
else
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) *.$(GSWAPP_EXTENSION))
endif

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj *.gswa *.debug *.profile)

GSWAPPS_WITH_SUBPROJECTS = $(strip $(foreach gswapp,$(GSWAPP_NAME),$(patsubst %,$(gswapp),$($(gswapp)_SUBPROJECTS))))
ifneq ($(GSWAPPS_WITH_SUBPROJECTS),)
internal-clean:: $(GSWAPPS_WITH_SUBPROJECTS:=.clean.gswapp.subprojects)
internal-distclean:: $(GSWAPPS_WITH_SUBPROJECTS:=.distclean.gswapp.subprojects)
endif

internal-strings:: $(GSWAPP_NAME:=.strings.gswapp.variables)

$(GSWAPP_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
	            $@.all.gswapp.variables
