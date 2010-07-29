#
#   Master/subproject.make
#
#   Master Makefile rules to build subprojects in GNUstep projects.
#
#   Copyright (C) 1998, 2001 Free Software Foundation, Inc.
#
#   Author:  Jonathan Gapen <jagapen@whitewater.chem.wisc.edu>
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

#
# The name of the subproject is in the SUBPROJECT_NAME variable.
#

SUBPROJECT_NAME := $(strip $(SUBPROJECT_NAME))

# Count the number of subprojects - we can support only one!
ifneq ($(words $(SUBPROJECT_NAME)), 1)

SUBPROJECT_NAME := $(word 1, $(SUBPROJECT_NAME))
$(warning Only a single subproject can be built in any directory!)
$(warning Ignoring all subprojects and building only $(SUBPROJECT_NAME))

endif

.PHONY: build-headers
build-headers:: $(SUBPROJECT_NAME:=.build-headers.subproject.variables)

internal-all:: $(SUBPROJECT_NAME:=.all.subproject.variables)

internal-install:: $(SUBPROJECT_NAME:=.install.subproject.variables)

internal-uninstall:: $(SUBPROJECT_NAME:=.uninstall.subproject.variables)

_PSWRAP_C_FILES = $($(SUBPROJECT_NAME)_PSWRAP_FILES:.psw=.c)
_PSWRAP_H_FILES = $($(SUBPROJECT_NAME)_PSWRAP_FILES:.psw=.h)

internal-clean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf $(GNUSTEP_OBJ_DIR_NAME) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES))
	rm -rf $(DERIVED_SOURCES_DIR)

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj)

SUBPROJECTS_WITH_SUBPROJECTS = $(strip $(patsubst %,$(SUBPROJECT_NAME),$($(SUBPROJECT_NAME)_SUBPROJECTS)))
ifneq ($(SUBPROJECTS_WITH_SUBPROJECTS),)
internal-clean:: $(SUBPROJECTS_WITH_SUBPROJECTS:=.clean.subproject.subprojects)
internal-distclean:: $(SUBPROJECTS_WITH_SUBPROJECTS:=.distclean.subproject.subprojects)
endif

# If the subproject has a resource bundle, destroy it on distclean
ifeq ($($(SUBPROJECT_NAME)_HAS_RESOURCE_BUNDLE), yes)
internal-distclean::
	rm -rf Resources
endif

internal-strings:: $(SUBPROJECT_NAME:=.strings.subproject.variables)

$(SUBPROJECT_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
		$@.all.subproject.variables
