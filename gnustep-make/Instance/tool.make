#   -*-makefile-*-
#   Instance/tool.make
#
#   Instance Makefile rules to build GNUstep-based command line tools.
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
# The name of the tools is in the TOOL_NAME variable.
#
# xxx We need to prefix the target name when cross-compiling
#

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

include $(GNUSTEP_MAKEFILES)/Instance/Shared/pch.make

.PHONY: internal-tool-all_       \
        internal-tool-install_   \
        internal-tool-uninstall_ \
        internal-tool-copy_into_dir

# This is the directory where the tools get installed. If you don't specify a
# directory they will get installed in the GNUstep Local Root.
ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  TOOL_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(TOOL_INSTALL_DIR),)
  TOOL_INSTALL_DIR = $(GNUSTEP_TOOLS)
endif

# This is the 'final' directory in which we copy the tool executable, including
# the target and library-combo paths.  You can override it in special occasions
# (eg, installing an executable into a web server's cgi dir).
ifeq ($(FINAL_TOOL_INSTALL_DIR),)
  FINAL_TOOL_INSTALL_DIR = $(TOOL_INSTALL_DIR)/$(GNUSTEP_TARGET_LDIR)
endif

ALL_TOOL_LIBS =								\
    $(shell $(WHICH_LIB_SCRIPT)						\
       $(ALL_LIB_DIRS)							\
       $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS) $(FND_LIBS)	\
       $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) $(OBJC_LIBS)	\
       $(TARGET_SYSTEM_LIBS)						\
	debug=$(debug) profile=$(profile) shared=$(shared)		\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

#
# Compilation targets
#
internal-tool-all_:: $(GNUSTEP_OBJ_DIR) \
		     shared-instance-pch-all \
                     $(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)

$(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT): $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING)$(LD) $(ALL_LDFLAGS) $(CC_LDFLAGS) -o $(LDOUT)$@ \
		$(OBJ_FILES_TO_LINK) \
		$(ALL_TOOL_LIBS)$(END_ECHO)

internal-tool-copy_into_dir::
	$(ECHO_COPYING_INTO_DIR)$(MKDIRS) $(COPY_INTO_DIR)/$(GNUSTEP_TARGET_LDIR);\
	  $(INSTALL_PROGRAM) -m 0755 \
	  $(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT) \
	  $(COPY_INTO_DIR)/$(GNUSTEP_TARGET_LDIR)$(END_ECHO)

# This rule runs $(MKDIRS) only if needed
$(FINAL_TOOL_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-tool-install_:: $(FINAL_TOOL_INSTALL_DIR)
	$(ECHO_INSTALLING)$(INSTALL_PROGRAM) -m 0755 \
		$(GNUSTEP_OBJ_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT) \
		$(FINAL_TOOL_INSTALL_DIR)$(END_ECHO)

internal-tool-uninstall_::
	rm -f $(FINAL_TOOL_INSTALL_DIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)

# NB: We don't have any cleaning targets for tools here, because we
# clean during the Master make invocation.

#
# If the user makefile contains the command
# xxx_HAS_RESOURCE_BUNDLE = yes
# then we need to build a resource bundle for the tool, and install it.
# You can then add resources to the tool, any sort of, with the usual
# xxx_RESOURCE_FILES, xxx_LOCALIZED_RESOURCE_FILES, xxx_LANGUAGES, etc.
# The tool resource bundle (and all resources inside it) can be
# accessed at runtime very comfortably, by using gnustep-base's
# [NSBundle +mainBundle] (exactly as you would do for an application).
#
ifeq ($($(GNUSTEP_INSTANCE)_HAS_RESOURCE_BUNDLE),yes)

# Include the rules to build resource bundles
GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = Resources/$(GNUSTEP_INSTANCE)
GNUSTEP_SHARED_BUNDLE_MAIN_PATH     = Resources/$(GNUSTEP_INSTANCE)
GNUSTEP_SHARED_BUNDLE_INSTALL_DIR = $(TOOL_INSTALL_DIR)
include $(GNUSTEP_MAKEFILES)/Instance/Shared/bundle.make

internal-tool-all_:: shared-instance-bundle-all
internal-tool-copy_into_dir:: shared-instance-bundle-copy_into_dir

$(TOOL_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

$(TOOL_INSTALL_DIR)/Resources:
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-tool-install_:: $(TOOL_INSTALL_DIR)/Resources \
                    shared-instance-bundle-install 

internal-tool-uninstall:: shared-instance-bundle-uninstall

endif

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make
