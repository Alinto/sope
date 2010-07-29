#
#   Master/gcj-java-tool.make
#
#   Master Makefile rules to build GNUstep-based command line ctools.
#
#   Copyright (C) 1997, 2001, 2006 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Nicola Pero <nicola@brainstorm.co.uk>
#   Author:  Helge Hess <helge.hess@opengroupware.org>
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

AOT_JAVA_TOOL_NAME := $(strip $(AOT_JAVA_TOOL_NAME))

internal-all:: $(AOT_JAVA_TOOL_NAME:=.all.aotjavatool.variables)

internal-install:: $(AOT_JAVA_TOOL_NAME:=.install.aotjavatool.variables)

internal-uninstall:: $(AOT_JAVA_TOOL_NAME:=.uninstall.aotjavatool.variables)

internal-clean::
	rm -rf $(GNUSTEP_OBJ_DIR)

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj)

AOT_JAVA_TOOLS_WITH_SUBPROJECTS = $(strip $(foreach aotjavatool,$(AOT_JAVA_TOOL_NAME),$(patsubst %,$(aotjavatool),$($(aotjavatool)_SUBPROJECTS))))
ifneq ($(AOT_JAVA_TOOLS_WITH_SUBPROJECTS),)
internal-clean:: $(AOT_JAVA_TOOLS_WITH_SUBPROJECTS:=.clean.aotjavatool.subprojects)
internal-distclean:: $(AOT_JAVA_TOOLS_WITH_SUBPROJECTS:=.distclean.aotjavatool.subprojects)
endif

internal-strings:: $(AOT_JAVA_TOOL_NAME:=.strings.aotjavatool.variables)

$(AOT_JAVA_TOOL_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
	         $@.all.aotjavatool.variables
