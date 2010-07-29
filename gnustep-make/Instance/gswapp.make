#
#   Instance/gswapp.make
#
#   Instance Makefile rules to build GNUstep web based applications.
#
#   Copyright (C) 1997-2004 Free Software Foundation, Inc.
#
#   Author:  Manuel Guesdon <mguesdon@sbuilders.com>,
#            Nicola Pero <n.pero@mi.flashnet.it>
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

# FIXME/TODO - this file has not been updated to use
# Instance/Shared/bundle.make because it is linking resources instead of
# copying them.


# The name of the application is in the GSWAPP_NAME variable.
# The list of languages the app is localized in are in xxx_LANGUAGES <==
# The list of application resource file are in xxx_RESOURCE_FILES
# The list of localized application resource file are in 
#  xxx_LOCALIZED_RESOURCE_FILES <==
# The list of application resource directories are in xxx_RESOURCE_DIRS
# The list of application web server resource directories are in 
#  xxx_WEBSERVER_RESOURCE_DIRS <==
# The list of localized application web server resource directories are in 
#  xxx_LOCALIZED_WEBSERVER_RESOURCE_DIRS
# where xxx is the application name <==

# Determine the application directory extension
ifeq ($(profile), yes)
  GSWAPP_EXTENSION = profile
else
  ifeq ($(debug), yes)
    GSWAPP_EXTENSION = debug
  else
    GSWAPP_EXTENSION = gswa
  endif
endif

GNUSTEP_GSWAPPS = $(GNUSTEP_INSTALLATION_DIR)/GSWApps

.PHONY: internal-gswapp-all_ \
        internal-gswapp-install_ \
        internal-gswapp-uninstall_ \
        internal-gswapp-copy_into_dir

#
# Determine where to install.  By default, install into GNUSTEP_GSWAPPS.
#
ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  GSWAPP_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(GSWAPP_INSTALL_DIR),)
  GSWAPP_INSTALL_DIR = $(GNUSTEP_GSWAPPS)
endif

# Libraries that go before the WO libraries
ALL_GSW_LIBS =								\
    $(shell $(WHICH_LIB_SCRIPT)						\
	$(ALL_LIB_DIRS)							\
	$(ADDITIONAL_GSW_LIBS) $(AUXILIARY_GSW_LIBS) $(GSW_LIBS)	\
	$(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS)			\
	$(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS)	\
        $(OBJC_LIBS) $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)		\
	debug=$(debug) profile=$(profile) shared=$(shared)		\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

GSWAPP_DIR_NAME = $(GNUSTEP_INSTANCE:=.$(GSWAPP_EXTENSION))
GSWAPP_DIR = $(GNUSTEP_BUILD_DIR)/$(GSWAPP_DIR_NAME)

#
# Now include the standard resource-bundle routines from Shared/bundle.make
#

ifneq ($(FOUNDATION_LIB), apple)
  # GNUstep bundle
  GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(GSWAPP_DIR)/Resources
  GSWAPP_INFO_PLIST_FILE = $(GSWAPP_DIR)/Resources/Info-gnustep.plist
else
  # OSX bundle
  GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(GSWAPP_DIR)/Contents/Resources
  GSWAPP_INFO_PLIST_FILE = $(GSWAPP_DIR)/Contents/Info.plist
endif
GNUSTEP_SHARED_BUNDLE_MAIN_PATH = $(GSWAPP_DIR_NAME)
GNUSTEP_SHARED_BUNDLE_INSTALL_DIR = $(GSWAPP_INSTALL_DIR)
include $(GNUSTEP_MAKEFILES)/Instance/Shared/bundle.make

ifneq ($(FOUNDATION_LIB), apple)
GSWAPP_FILE_NAME = $(GSWAPP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)
else
GSWAPP_FILE_NAME = $(GSWAPP_DIR_NAME)/Contents/MacOS/$(GNUSTEP_INSTANCE)$(EXEEXT)
endif

GSWAPP_FILE = $(GNUSTEP_BUILD_DIR)/$(GSWAPP_FILE_NAME)

#
# Internal targets
#

$(GSWAPP_FILE): $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING)$(LD) $(ALL_LDFLAGS) $(CC_LDFLAGS) -o $(LDOUT)$@ \
	$(OBJ_FILES_TO_LINK) $(ALL_GSW_LIBS)$(END_ECHO)
ifneq ($(FOUNDATION_LIB), apple)
	$(ECHO_NOTHING)$(TRANSFORM_PATHS_SCRIPT) $(subst -L,,$(ALL_LIB_DIRS)) \
	        >$(GSWAPP_DIR)/$(GNUSTEP_TARGET_LDIR)/library_paths.openapp$(END_ECHO)
endif

#
# Compilation targets
#
ifeq ($(FOUNDATION_LIB), apple)
internal-gswapp-all_:: \
	$(GNUSTEP_OBJ_DIR) \
        $(GSWAPP_DIR)/Contents/MacOS \
        $(GSWAPP_FILE) \
        shared-instance-bundle-all \
        $(GSWAPP_INFO_PLIST_FILE)

$(GSWAPP_DIR)/Contents/MacOS:
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)
else

internal-gswapp-all_:: $(GNUSTEP_OBJ_DIR) \
                    $(GSWAPP_DIR)/$(GNUSTEP_TARGET_LDIR) \
                    $(GSWAPP_FILE) \
                    $(GSWAPP_DIR)/Resources \
                    $(GSWAPP_INFO_PLIST_FILE) \
                    shared-instance-bundle-all

$(GSWAPP_DIR)/$(GNUSTEP_TARGET_LDIR):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

endif

PRINCIPAL_CLASS = $(strip $($(GNUSTEP_INSTANCE)_PRINCIPAL_CLASS))

ifeq ($(PRINCIPAL_CLASS),)
  PRINCIPAL_CLASS = $(GNUSTEP_INSTANCE)
endif

HAS_GSWCOMPONENTS = $($(GNUSTEP_INSTANCE)_HAS_GSWCOMPONENTS)
GSWAPP_INFO_PLIST = $($(GNUSTEP_INSTANCE)_GSWAPP_INFO_PLIST)
MAIN_MODEL_FILE = $(strip $(subst .gmodel,,$(subst .gorm,,$(subst .nib,,$($(GNUSTEP_INSTANCE)_MAIN_MODEL_FILE)))))

$(GSWAPP_INFO_PLIST_FILE):
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)\";"; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  if [ "$(HAS_GSWCOMPONENTS)" != "" ]; then \
	    echo "  HasGSWComponents = \"$(HAS_GSWCOMPONENTS)\";"; \
	  fi; \
	  echo "  NSMainNibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  if [ -r "$(GNUSTEP_INSTANCE)Info.plist" ]; then \
	    cat $(GNUSTEP_INSTANCE)Info.plist; \
	  fi; \
	  if [ "$(GSWAPP_INFO_PLIST)" != "" ]; then \
	    cat $(GSWAPP_INFO_PLIST); \
	  fi; \
	  echo "}") >$@$(END_ECHO)

internal-gswapp-copy_into_dir:: shared-instance-bundle-copy_into_dir

# install/uninstall targets

$(GSWAPP_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-gswapp-install_:: shared-instance-bundle-install
ifeq ($(strip),yes)
	$(ECHO_STRIPPING)$(STRIP) $(GSWAPP_INSTALL_DIR)/$(GSWAPP_FILE_NAME)$(END_ECHO)
endif

internal-gswapp-uninstall_:: shared-instance-bundle-uninstall

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make
