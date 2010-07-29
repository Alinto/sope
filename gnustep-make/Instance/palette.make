#
#   Instance/palette.make
#
#   Instance Makefile rules to build GNUstep-based palettes.
#
#   Copyright (C) 1999 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
#   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
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

# The name of the palette is in the PALETTE_NAME variable.
# The list of palette resource file are in xxx_RESOURCE_FILES
# The list of palette resource directories are in xxx_RESOURCE_DIRS
# The name of the palette class is xxx_PRINCIPAL_CLASS
# The name of the palette nib is xxx_MAIN_MODEL_FILE
# The name of the palette icon is xxx_PALETTE_ICON
# The name of a file containing info.plist entries to be inserted into
# Info-gnustep.plist (if any) is xxxInfo.plist where xxx is the palette name
# The name of a file containing palette.table entries to be inserted into
# palette.table (if any) is xxxpalette.table where xxx is the palette name
#

.PHONY: internal-palette-all_ \
        internal-palette-install_ \
        internal-palette-uninstall_ \
        internal-palette-copy_into_dir

# On Solaris we don't need to specifies the libraries the palette needs.
# How about the rest of the systems? ALL_PALETTE_LIBS is temporary empty.
#ALL_PALETTE_LIBS = $(ADDITIONAL_GUI_LIBS) $(AUXILIARY_GUI_LIBS) $(BACKEND_LIBS) \
#   $(GUI_LIBS) $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS) \
#   $(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) $(OBJC_LIBS) \
#   $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)

#ALL_PALETTE_LIBS := \
#    $(shell $(WHICH_LIB_SCRIPT) $(ALL_LIB_DIRS) $(ALL_PALETTE_LIBS) \
#	debug=$(debug) profile=$(profile) shared=$(shared) libext=$(LIBEXT) \
#	shared_libext=$(SHARED_LIBEXT))
# On windows, this is unfortunately required.

ifeq ($(BUILD_DLL), yes)
  LINK_PALETTE_AGAINST_ALL_LIBS = yes
endif

# On Apple, two-level namespaces require all symbols in bundles
# to be resolved at link time.
ifeq ($(FOUNDATION_LIB), apple)
  LINK_PALETTE_AGAINST_ALL_LIBS = yes
endif

ifeq ($(LINK_PALETTE_AGAINST_ALL_LIBS), yes)
PALETTE_LIBS += $(ADDITIONAL_GUI_LIBS) $(AUXILIARY_GUI_LIBS) $(BACKEND_LIBS) \
   $(GUI_LIBS) $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS) \
   $(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) $(OBJC_LIBS) \
   $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)
endif

ALL_PALETTE_LIBS =						\
    $(shell $(WHICH_LIB_SCRIPT)					\
	$(ALL_LIB_DIRS)						\
	$(PALETTE_LIBS)						\
	debug=$(debug) profile=$(profile) shared=$(shared)	\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

ifeq ($(BUILD_DLL),yes)
PALETTE_OBJ_EXT = $(DLL_LIBEXT)
endif

PALETTE_DIR_NAME = $(GNUSTEP_INSTANCE).palette
PALETTE_DIR = $(GNUSTEP_BUILD_DIR)/$(PALETTE_DIR_NAME)
PALETTE_FILE_NAME = $(PALETTE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(PALETTE_NAME)$(PALETTE_OBJ_EXT)
PALETTE_FILE = $(GNUSTEP_BUILD_DIR)/$(PALETTE_FILE_NAME)

ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  PALETTE_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(PALETTE_INSTALL_DIR),)
  PALETTE_INSTALL_DIR = $(GNUSTEP_PALETTES)
endif

GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(PALETTE_DIR)/Resources
GNUSTEP_SHARED_BUNDLE_MAIN_PATH = $(PALETTE_DIR_NAME)
GNUSTEP_SHARED_BUNDLE_INSTALL_DIR = $(PALETTE_INSTALL_DIR)
include $(GNUSTEP_MAKEFILES)/Instance/Shared/bundle.make

internal-palette-all_:: $(GNUSTEP_OBJ_DIR) \
                        $(PALETTE_DIR)/Resources \
                        $(PALETTE_DIR)/$(GNUSTEP_TARGET_LDIR) \
                        $(PALETTE_FILE) \
                        $(PALETTE_DIR)/Resources/Info-gnustep.plist \
                        $(PALETTE_DIR)/Resources/palette.table \
                        shared-instance-bundle-all

$(PALETTE_DIR)/$(GNUSTEP_TARGET_LDIR):
	$(ECHO_CREATING)$(MKDIRS) $(PALETTE_DIR)/$(GNUSTEP_TARGET_LDIR)$(END_ECHO)

# Standard bundle build using the rules for this target
$(PALETTE_FILE) : $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING)$(BUNDLE_LD) $(BUNDLE_LDFLAGS) \
	  -o $(LDOUT)$(PALETTE_FILE) \
	  $(OBJ_FILES_TO_LINK) $(ALL_LDFLAGS) \
	  $(BUNDLE_LIBFLAGS) $(ALL_PALETTE_LIBS)$(END_ECHO)

PRINCIPAL_CLASS = $(strip $($(GNUSTEP_INSTANCE)_PRINCIPAL_CLASS))

ifeq ($(PRINCIPAL_CLASS),)
  PRINCIPAL_CLASS = $(GNUSTEP_INSTANCE)
endif

PALETTE_ICON = $($(GNUSTEP_INSTANCE)_PALETTE_ICON)

ifeq ($(PALETTE_ICON),)
  PALETTE_ICON = $(GNUSTEP_INSTANCE)
endif

$(PALETTE_DIR)/Resources/Info-gnustep.plist: $(PALETTE_DIR)/Resources
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(PALETTE_NAME)$(PALETTE_OBJ_EXT)\";"; \
	  if [ -r "$(GNUSTEP_INSTANCE)Info.plist" ]; then \
	    cat $(GNUSTEP_INSTANCE)Info.plist; \
	  fi; \
	  echo "}") >$@$(END_ECHO)

MAIN_MODEL_FILE = $(strip $(subst .gmodel,,$(subst .gorm,,$(subst .nib,,$($(GNUSTEP_INSTANCE)_MAIN_MODEL_FILE)))))

$(PALETTE_DIR)/Resources/palette.table: $(PALETTE_DIR)/Resources
	$(ECHO_CREATING)(echo "{";\
	  echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  echo "  Class = \"$(PRINCIPAL_CLASS)\";"; \
	  echo "  Icon = \"$(PALETTE_ICON)\";"; \
	  echo "}"; \
	  if [ -r "$(GNUSTEP_INSTANCE)palette.table" ]; then \
	    cat $(GNUSTEP_INSTANCE)palette.table; \
	  fi; \
	  ) >$@$(END_ECHO)

internal-palette-copy_into_dir:: shared-instance-bundle-copy_into_dir

#
# Install targets
#
$(PALETTE_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-palette-install_:: shared-instance-bundle-install
ifeq ($(strip),yes)
	$(ECHO_STRIPPING)$(STRIP) $(PALETTE_INSTALL_DIR)/$(PALETTE_FILE_NAME)$(END_ECHO)
endif

internal-palette-uninstall_:: shared-instance-bundle-uninstall


include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make
