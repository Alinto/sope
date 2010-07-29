#
#   Master/tool.make
#
#   Master Makefile rules to build GNUstep-based command line tools.
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

TOOL_NAME := $(strip $(TOOL_NAME))

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

internal-all:: $(TOOL_NAME:=.all.tool.variables)

internal-install:: $(TOOL_NAME:=.install.tool.variables)

internal-uninstall:: $(TOOL_NAME:=.uninstall.tool.variables)

internal-clean::
	rm -rf $(GNUSTEP_OBJ_DIR)
	rm -rf $(DERIVED_SOURCES_DIR)

internal-distclean::
	(cd $(GNUSTEP_BUILD_DIR); \
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj)

TOOLS_WITH_SUBPROJECTS = $(strip $(foreach tool,$(TOOL_NAME),$(patsubst %,$(tool),$($(tool)_SUBPROJECTS))))
ifneq ($(TOOLS_WITH_SUBPROJECTS),)
internal-clean:: $(TOOLS_WITH_SUBPROJECTS:=.clean.tool.subprojects)
internal-distclean:: $(TOOLS_WITH_SUBPROJECTS:=.distclean.tool.subprojects)
endif

# On distclean, we also want to efficiently wipe out the Resources/
# directory if (and only if) there are tools for which
# xxx_HAS_RESOURCE_BUNDLE=yes
TOOLS_WITH_RESOURCE_BUNDLES = $(strip $(foreach tool,$(TOOL_NAME),$($(tool)_HAS_RESOURCE_BUNDLE:yes=$(tool))))

ifneq ($(TOOLS_WITH_RESOURCE_BUNDLES),)
internal-distclean::
	rm -rf Resources
endif

internal-strings:: $(TOOL_NAME:=.strings.tool.variables)

$(TOOL_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory --no-keep-going \
	         $@.all.tool.variables
