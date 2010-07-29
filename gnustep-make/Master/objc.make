#
#   Master/objc.make
#
#   Master Makefile rules to build ObjC-based (but not GNUstep) programs.
#
#   Copyright (C) 1997, 2001 Free Software Foundation, Inc.
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

OBJC_PROGRAM_NAME := $(strip $(OBJC_PROGRAM_NAME))

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

internal-all:: $(OBJC_PROGRAM_NAME:=.all.objc-program.variables)

internal-install:: $(OBJC_PROGRAM_NAME:=.install.objc-program.variables)

internal-uninstall:: $(OBJC_PROGRAM_NAME:=.uninstall.objc-program.variables)

internal-clean::
	rm -rf $(GNUSTEP_OBJ_DIR)

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj)

OBJC_PROGRAMS_WITH_SUBPROJECTS = $(strip $(foreach objc_program,$(OBJC_PROGRAM_NAME),$(patsubst %,$(objc_program),$($(objc_program)_SUBPROJECTS))))
ifneq ($(OBJC_PROGRAMS_WITH_SUBPROJECTS),)
internal-clean:: $(OBJC_PROGRAMS_WITH_SUBPROJECTS:=.clean.objc-program.subprojects)
internal-distclean:: $(OBJC_PROGRAMS_WITH_SUBPROJECTS:=.distclean.objc-program.subprojects)
endif

internal-strings:: $(OBJC_PROGRAM_NAME:=.strings.objc-program.variables)

$(OBJC_PROGRAM_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
		$@.all.objc-program.variables
