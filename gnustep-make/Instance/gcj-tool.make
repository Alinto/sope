#
#   Instance/gcj-java-tool.make
#
#   Instance Makefile rules to build GNUstep-based command line gcj tools.
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

#
# The name of the GCJ compiled tools is in the AOT_JAVA_TOOL_NAME variable.
# The name of the app class is xxx_MAIN_CLASS (defaults to tool name).
#
# xxx We need to prefix the target name when cross-compiling
#

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

MAIN_CLASS = $(strip $($(GNUSTEP_INSTANCE)_MAIN_CLASS))

ifeq ($(MAIN_CLASS),)
  MAIN_CLASS = $(AOT_JAVA_TOOL_NAME)
endif

CC:=gcj # TODO: make configurable
LD:=gcj # TODO: make configurable
ALL_LDFLAGS += --main=$(MAIN_CLASS)

# This is the directory where the aotjavatools get installed. If you don't
# specify a directory they will get installed in the GNUstep Local
# root.
ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  AOT_JAVA_TOOL_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(AOT_JAVA_TOOL_INSTALL_DIR),)
  AOT_JAVA_TOOL_INSTALL_DIR = $(GNUSTEP_TOOLS)
endif

.PHONY: internal-aotjavatool-all_ \
        internal-aotjavatool-install_ \
        internal-aotjavatool-uninstall_

ALL_TOOL_LIBS =							\
    $(shell $(WHICH_LIB_SCRIPT)					\
     $(ALL_LIB_DIRS)						\
     $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS)		\
     $(TARGET_SYSTEM_LIBS)					\
	debug=$(debug) profile=$(profile) shared=$(shared)	\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

#
# Compilation targets
#
internal-aotjavatool-all_:: $(GNUSTEP_OBJ_DIR) \
	              $(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)

$(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT): $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING)$(LD) $(ALL_LDFLAGS) -o $(LDOUT)$@ \
	      $(OBJ_FILES_TO_LINK) \
	      $(ALL_TOOL_LIBS)$(END_ECHO)

internal-aotjavatool-install_:: $(AOT_JAVA_TOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR)
	$(ECHO_INSTALLING)$(INSTALL_PROGRAM) -m 0755 \
	                   $(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT) \
	                   $(AOT_JAVA_TOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR)$(END_ECHO)

$(AOT_JAVA_TOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-aotjavatool-uninstall_::
	$(ECHO_UNINSTALLING)rm -f $(AOT_JAVA_TOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)$(END_ECHO)

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make

