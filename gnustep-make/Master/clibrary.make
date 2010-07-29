#
#   Master/clibrary.make
#
#   Master Makefile rules to build C libraries.
#
#   Copyright (C) 1997, 2001 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#	     Ovidiu Predescu <ovidiu@net-community.com>
#            Nicola Pero     <nicola@brainstorm.co.uk>
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

CLIBRARY_NAME := $(strip $(CLIBRARY_NAME))

internal-all:: $(CLIBRARY_NAME:=.all.clibrary.variables)

internal-install:: $(CLIBRARY_NAME:=.install.clibrary.variables)

internal-uninstall:: $(CLIBRARY_NAME:=.uninstall.clibrary.variables)

_PSWRAP_C_FILES = $(foreach lib,$(CLIBRARY_NAME),$($(lib)_PSWRAP_FILES:.psw=.c))
_PSWRAP_H_FILES = $(foreach lib,$(CLIBRARY_NAME),$($(lib)_PSWRAP_FILES:.psw=.h))

internal-clean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES))

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj)

CLIBRARIES_WITH_SUBPROJECTS = $(strip $(foreach clibrary,$(CLIBRARY_NAME),$(patsubst %,$(clibrary),$($(clibrary)_SUBPROJECTS))))
ifneq ($(CLIBRARIES_WITH_SUBPROJECTS),)
internal-clean:: $(CLIBRARIES_WITH_SUBPROJECTS:=.clean.clibrary.subprojects)
internal-distclean:: $(CLIBRARIES_WITH_SUBPROJECTS:=.distclean.clibrary.subprojects)
endif

internal-strings:: $(CLIBRARY_NAME:=.strings.clibrary.variables)

$(CLIBRARY_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
		$@.all.clibrary.variables
