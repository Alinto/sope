#
#   Instance/ctool.make
#
#   Instance Makefile rules to build GNUstep-based command line ctools.
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

#
# The name of the ctools is in the CTOOL_NAME variable.
#
# xxx We need to prefix the target name when cross-compiling
#

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

# This is the directory where the ctools get installed. If you don't
# specify a directory they will get installed in the GNUstep Local
# root.
ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  CTOOL_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(CTOOL_INSTALL_DIR),)
  CTOOL_INSTALL_DIR = $(GNUSTEP_TOOLS)
endif

.PHONY: internal-ctool-all_ \
        internal-ctool-install_ \
        internal-ctool-uninstall_

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
internal-ctool-all_:: $(GNUSTEP_OBJ_DIR) \
	              $(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)

$(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT): $(C_OBJ_FILES) \
                                                 $(SUBPROJECT_OBJ_FILES)
	$(ECHO_LINKING)$(LD) $(ALL_LDFLAGS) -o $(LDOUT)$@ \
	      $(C_OBJ_FILES) $(SUBPROJECT_OBJ_FILES) \
	      $(ALL_TOOL_LIBS)$(END_ECHO)

internal-ctool-install_:: $(CTOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR)
	$(ECHO_INSTALLING)$(INSTALL_PROGRAM) -m 0755 \
	                   $(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT) \
	                   $(CTOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR)$(END_ECHO)

$(CTOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-ctool-uninstall_::
	$(ECHO_UNINSTALLING)rm -f $(CTOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)$(END_ECHO)

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make

