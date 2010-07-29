#
#   Instace/bundle.make
#
#   Instance makefile rules to build GNUstep-based bundles.
#
#   Copyright (C) 1997, 2001, 2002 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
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

include $(GNUSTEP_MAKEFILES)/Instance/Shared/headers.make
include $(GNUSTEP_MAKEFILES)/Instance/Shared/pch.make

# The name of the bundle is in the BUNDLE_NAME variable.
# The list of bundle resource file are in xxx_RESOURCE_FILES
# The list of localized bundle resource files is in 
#                               xxx_LOCALIZED_RESOURCE_FILES
# The list of languages the bundle supports is in xxx_LANGUAGES
# The list of bundle resource directories are in xxx_RESOURCE_DIRS
# The name of the principal class is xxx_PRINCIPAL_CLASS
# The header files are in xxx_HEADER_FILES
# The directory where the header files are located is xxx_HEADER_FILES_DIR
# The directory where to install the header files inside the library
# installation directory is xxx_HEADER_FILES_INSTALL_DIR
# where xxx is the bundle name
#

.PHONY: internal-bundle-all_ \
        internal-bundle-install_ \
        internal-bundle-uninstall_ \
        internal-bundle-copy_into_dir \
        build-bundle

# In some cases, a bundle without any object file in it is useful - to
# just store some resources which can be loaded comfortably using the 
# gnustep-base NSBundle API.  In this case - which we detect because
# OBJ_FILES_TO_LINK is empty - we skip any code related to linking etc
ifneq ($(OBJ_FILES_TO_LINK),)
# NB: we don't need to link the bundle against the system libraries,
# which are already linked in the application ... linking them both in
# the bundle and in the application would just make things more
# difficult when the bundle is loaded (eg, if the application and the
# bundle end up being linked to different versions of the system
# libraries ...)

# On windows, this is unfortunately required.
ifeq ($(BUILD_DLL), yes)
  LINK_BUNDLE_AGAINST_ALL_LIBS = yes
endif

# Apple CC two-level namespaces requires all symbols in bundles
# to be resolved at link time.
ifeq ($(CC_BUNDLE), yes)
  LINK_BUNDLE_AGAINST_ALL_LIBS = yes
endif

ifeq ($(LINK_BUNDLE_AGAINST_ALL_LIBS), yes)
BUNDLE_LIBS += $(ADDITIONAL_GUI_LIBS) $(AUXILIARY_GUI_LIBS) $(BACKEND_LIBS) \
   $(GUI_LIBS) $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS) \
   $(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) $(OBJC_LIBS) \
   $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)
endif

ALL_BUNDLE_LIBS =						\
    $(shell $(WHICH_LIB_SCRIPT)					\
	$(ALL_LIB_DIRS)						\
	$(BUNDLE_LIBS)						\
	debug=$(debug) profile=$(profile) shared=$(shared)	\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

ifeq ($(BUILD_DLL),yes)
BUNDLE_OBJ_EXT = $(DLL_LIBEXT)
endif

endif # OBJ_FILES_TO_LINK

#
# GNUstep bundles are built in the following way on all platforms:
# xxx.bundle/Resources/Info-gnustep.plist
# xxx.bundle/Resources/<all resources here>
#
# We also support building Apple bundles using Apple frameworks
# on Apple platforms - in which case, the bundle has a different
# structure:
# xxx.bundle/Contents/Info.plist
# xxx.bundle/Contents/Resources/<all resources here>
# This second way of building bundles is triggered by FOUNDATION_LIB =
# apple.
#

internal-bundle-all_:: $(GNUSTEP_OBJ_DIR) \
		       shared-instance-pch-all \
		       build-bundle

BUNDLE_DIR_NAME = $(GNUSTEP_INSTANCE:=$(BUNDLE_EXTENSION))
BUNDLE_DIR = $(GNUSTEP_BUILD_DIR)/$(BUNDLE_DIR_NAME)

ifneq ($(OBJ_FILES_TO_LINK),)
  ifneq ($(FOUNDATION_LIB), apple)
    BUNDLE_FILE_NAME = \
      $(BUNDLE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE)$(BUNDLE_OBJ_EXT)
  else
    BUNDLE_FILE_NAME = \
      $(BUNDLE_DIR_NAME)/Contents/MacOS/$(GNUSTEP_INSTANCE)$(BUNDLE_OBJ_EXT)
  endif

  BUNDLE_FILE = $(GNUSTEP_BUILD_DIR)/$(BUNDLE_FILE_NAME)
endif

#
# Determine where to install.  By default, install into GNUSTEP_BUNDLES.
#
ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  BUNDLE_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(BUNDLE_INSTALL_DIR),)
  BUNDLE_INSTALL_DIR = $(GNUSTEP_BUNDLES)
endif

ifneq ($(FOUNDATION_LIB), apple)
  # GNUstep bundle
  GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(BUNDLE_DIR)/Resources
  BUNDLE_INFO_PLIST_FILE = $(BUNDLE_DIR)/Resources/Info-gnustep.plist
else
  # OSX bundle
  GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(BUNDLE_DIR)/Contents/Resources
  BUNDLE_INFO_PLIST_FILE = $(BUNDLE_DIR)/Contents/Info.plist
endif
GNUSTEP_SHARED_BUNDLE_MAIN_PATH = $(BUNDLE_DIR_NAME)
GNUSTEP_SHARED_BUNDLE_INSTALL_DIR = $(BUNDLE_INSTALL_DIR)
include $(GNUSTEP_MAKEFILES)/Instance/Shared/bundle.make

ifneq ($(OBJ_FILES_TO_LINK),)
ifneq ($(FOUNDATION_LIB),apple)
build-bundle: $(BUNDLE_DIR)/$(GNUSTEP_TARGET_LDIR) \
              $(BUNDLE_FILE) \
              $(BUNDLE_INFO_PLIST_FILE) \
              shared-instance-bundle-all
else
build-bundle: $(BUNDLE_DIR)/Contents/MacOS \
              $(BUNDLE_FILE) \
              $(BUNDLE_INFO_PLIST_FILE) \
              shared-instance-bundle-all
endif

# The rule to build $(BUNDLE_DIR)/Resources is already provided
# by Instance/Shared/bundle.make

$(BUNDLE_DIR)/$(GNUSTEP_TARGET_LDIR):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

$(BUNDLE_FILE): $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING)$(BUNDLE_LINK_CMD)$(END_ECHO)

PRINCIPAL_CLASS = $(strip $($(GNUSTEP_INSTANCE)_PRINCIPAL_CLASS))

ifeq ($(PRINCIPAL_CLASS),)
  PRINCIPAL_CLASS = $(GNUSTEP_INSTANCE)
endif

else 
# Following code for the case OBJ_FILES_TO_LINK is empty - bundle with
# no shared object in it.
build-bundle: $(BUNDLE_INFO_PLIST_FILE) shared-instance-bundle-all
endif # OBJ_FILES_TO_LINK

MAIN_MODEL_FILE = $(strip $(subst .gmodel,,$(subst .gorm,,$(subst .nib,,$($(GNUSTEP_INSTANCE)_MAIN_MODEL_FILE)))))

# We must recreate Info.plist if the values of PRINCIPAL_CLASS and/or
# of MAIN_MODEL_FILE has changed since last time we built Info.plist.
# We use stamp-string.make, which will store the variables in a stamp
# file inside GNUSTEP_STAMP_DIR, and rebuild Info.plist if
# GNUSTEP_STAMP_STRING changes
GNUSTEP_STAMP_STRING = $(PRINCIPAL_CLASS)-$(MAIN_MODEL_FILE)
ifneq ($(FOUNDATION_LIB), apple)
GNUSTEP_STAMP_DIR = $(BUNDLE_DIR)
else
# Everything goes in Contents/ on Apple
GNUSTEP_STAMP_DIR = $(BUNDLE_DIR)/Contents
endif

ifeq ($(FOUNDATION_LIB), apple)
# For efficiency, depend on the rule to build
# BUNDLE_DIR/Contents/Resources (which would be used anyway when
# building the bundle), so that first we use the rule to create
# BUNDLE_DIR/Contents/Resources, and then we can avoid executing a
# separate rule/subshell to create GNUSTEP_STAMP_DIR which has already
# been implicitly created by the other rule!
$(GNUSTEP_STAMP_DIR): $(BUNDLE_DIR)/Contents/Resources

else
$(GNUSTEP_STAMP_DIR): $(BUNDLE_DIR)/Resources

endif

include $(GNUSTEP_MAKEFILES)/Instance/Shared/stamp-string.make

ifeq ($(FOUNDATION_LIB), apple)
# MacOSX bundles

$(BUNDLE_DIR)/Contents:
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

$(BUNDLE_DIR)/Contents/MacOS:
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

ifneq ($(OBJ_FILES_TO_LINK),)
$(BUNDLE_DIR)/Contents/Info.plist: $(BUNDLE_DIR)/Contents \
                                        $(GNUSTEP_STAMP_DEPEND)
	$(ECHO_CREATING)(echo "<?xml version='1.0' encoding='utf-8'?>";\
	  echo "<!DOCTYPE plist SYSTEM 'file://localhost/System/Library/DTDs/PropertyList.dtd'>";\
	  echo "<!-- Automatically generated, do not edit! -->";\
	  echo "<plist version='0.9'>";\
	  echo "  <dict>";\
	  echo "    <key>CFBundleExecutable</key>";\
	  echo "    <string>$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE)$(BUNDLE_OBJ_EXT)</string>";\
	  echo "    <key>CFBundleInfoDictionaryVersion</key>";\
	  echo "    <string>6.0</string>";\
	  echo "    <key>CFBundlePackageType</key>";\
	  echo "    <string>BNDL</string>";\
	  echo "    <key>NSPrincipalClass</key>";\
	  echo "    <string>$(PRINCIPAL_CLASS)</string>";\
	  echo "  </dict>";\
	  echo "</plist>";\
	) >$@$(END_ECHO)
else
$(BUNDLE_DIR)/Contents/Info.plist: $(BUNDLE_DIR)/Contents \
                                        $(GNUSTEP_STAMP_DEPEND)
	$(ECHO_CREATING)(echo "<?xml version='1.0' encoding='utf-8'?>";\
	  echo "<!DOCTYPE plist SYSTEM 'file://localhost/System/Library/DTDs/PropertyList.dtd'>";\
	  echo "<!-- Automatically generated, do not edit! -->";\
	  echo "<plist version='0.9'>";\
	  echo "  <dict>";\
	  echo "    <key>CFBundleInfoDictionaryVersion</key>";\
	  echo "    <string>6.0</string>";\
	  echo "    <key>CFBundlePackageType</key>";\
	  echo "    <string>BNDL</string>";\
	  echo "  </dict>";\
	  echo "</plist>";\
	) >$@$(END_ECHO)
endif

else # following executed if FOUNDATION_LIB != apple

ifneq ($(OBJ_FILES_TO_LINK),)
# GNUstep bundles
$(BUNDLE_DIR)/Resources/Info-gnustep.plist: $(BUNDLE_DIR)/Resources \
                                                 $(GNUSTEP_STAMP_DEPEND)
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)$(BUNDLE_OBJ_EXT)\";"; \
	  echo "  NSMainNibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  echo "}") >$@$(END_ECHO)
	$(ECHO_NOTHING)if [ -r "$(GNUSTEP_INSTANCE)Info.plist" ]; then \
	  plmerge $@ $(GNUSTEP_INSTANCE)Info.plist; \
	fi$(END_ECHO)
else # following code for when no object file is built
# GNUstep bundles
$(BUNDLE_DIR)/Resources/Info-gnustep.plist: $(BUNDLE_DIR)/Resources \
                                                 $(GNUSTEP_STAMP_DEPEND)
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSMainNibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  echo "}") >$@$(END_ECHO)
	$(ECHO_NOTHING)if [ -r "$(GNUSTEP_INSTANCE)Info.plist" ]; then \
	  plmerge $@ $(GNUSTEP_INSTANCE)Info.plist; \
	fi$(END_ECHO)
endif

endif # FOUNDATION_LIB != apple

internal-bundle-copy_into_dir:: shared-instance-bundle-copy_into_dir

$(BUNDLE_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-bundle-install_:: shared-instance-headers-install \
                     shared-instance-bundle-install
ifeq ($(strip),yes)
ifneq ($(OBJ_FILES_TO_LINK),)
	$(ECHO_STRIPPING)$(STRIP) $(BUNDLE_INSTALL_DIR)/$(BUNDLE_FILE_NAME)$(END_ECHO)
endif
endif

internal-bundle-uninstall_:: shared-instance-headers-uninstall \
                       shared-instance-bundle-uninstall

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make

