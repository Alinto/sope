#   -*-makefile-*-
#   Instace/resource-set.make
#
#   Instance makefile rules to install resource files
#
#   Copyright (C) 2002 Free Software Foundation, Inc.
#
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
# The name of the set of resources is in the RESOURCE_SET_NAME variable.
# The list of resource file are in xxx_RESOURCE_FILES
# The list of resource directories to create are in xxx_RESOURCE_DIRS
# The directory in which to install the resources is in the
#                xxx_RESOURCE_FILES_INSTALL_DIR
# The directory in which the resources are is in the 
#                xxx_RESOURCE_FILES_DIR (defaults to ./ if omitted)
# The list of LANGUAGES is in the xxx_LANGUAGES variable.
# The list of localized files to be read from yyy.lproj and copied
#    into $(RESOURCE_FILES_INSTALL_DIR)/yyy.lproj for each language yyy
#    is in the xxx_LOCALIZED_RESOURCE_FILES variable.
#

.PHONY: internal-resource_set-install_ \
        internal-resource_set-uninstall_

# Determine installation dir
RESOURCE_FILES_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_RESOURCE_FILES_INSTALL_DIR)
RESOURCE_FILES_FULL_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/$(RESOURCE_FILES_INSTALL_DIR)

# Rule to build the installation dir
$(RESOURCE_FILES_FULL_INSTALL_DIR):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)


# Determine the additional installation dirs to build
RESOURCE_DIRS = $($(GNUSTEP_INSTANCE)_RESOURCE_DIRS)

ifneq ($(RESOURCE_DIRS),)
# Rule to build the additional installation dirs
$(addprefix $(RESOURCE_FILES_FULL_INSTALL_DIR)/,$(RESOURCE_DIRS)):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)
endif


# Determine the dir to take the resources from
RESOURCE_FILES_DIR = $($(GNUSTEP_INSTANCE)_RESOURCE_FILES_DIR)
ifeq ($(RESOURCE_FILES_DIR),)
  RESOURCE_FILES_DIR = ./
endif


# Determine the list of resource files
RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_RESOURCE_FILES)


# Determine the list of languages
override LANGUAGES = $($(GNUSTEP_INSTANCE)_LANGUAGES)
ifeq ($(LANGUAGES),)
  override LANGUAGES = English
endif


# Determine the list of localized resource files
LOCALIZED_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_LOCALIZED_RESOURCE_FILES)

#
# We provide two different algorithms of installing resource files.
#

ifeq ($(GNUSTEP_DEVELOPER),)

# Standard one - just run a subshell and loop, and install everything.
internal-resource_set-install_: \
  $(RESOURCE_FILES_FULL_INSTALL_DIR) \
  $(addprefix $(RESOURCE_FILES_FULL_INSTALL_DIR)/,$(RESOURCE_DIRS))
ifneq ($(RESOURCE_FILES),)
	$(ECHO_NOTHING)for file in $(RESOURCE_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $(RESOURCE_FILES_DIR)/$$file \
	                    $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$file; \
	  fi; \
	done$(END_ECHO)
endif
ifneq ($(LOCALIZED_RESOURCE_FILES),)
	$(ECHO_NOTHING)for l in $(LANGUAGES); do \
	  if [ -d $$l.lproj ]; then \
	    $(MKINSTALLDIRS) $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$l.lproj; \
	    for f in $(LOCALIZED_RESOURCE_FILES); do \
	      if [ -f $$l.lproj/$$f ]; then \
	        $(INSTALL_DATA) $$l.lproj/$$f \
	                        $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$l.lproj; \
	      else \
	        echo "Warning: $$l.lproj/$$f not found - ignoring"; \
	      fi; \
	    done; \
	  else \
	    echo "Warning: $$l.lproj not found - ignoring"; \
	  fi; \
	done$(END_ECHO)
endif

else # Following code turned on by setting GNUSTEP_DEVELOPER=YES in the shell

.PHONY: internal-resource-set-install-languages

# One optimized for recurrent installations during development - this
# rule installs a single file only if strictly needed
$(RESOURCE_FILES_FULL_INSTALL_DIR)/% : $(RESOURCE_FILES_DIR)/%
	$(ECHO_NOTHING)$(INSTALL_DATA) $< $@$(END_ECHO)

# This rule depends on having installed all files
internal-resource_set-install_: \
   $(RESOURCE_FILES_FULL_INSTALL_DIR) \
   $(addprefix $(RESOURCE_FILES_FULL_INSTALL_DIR)/,$(RESOURCE_DIRS)) \
   $(addprefix $(RESOURCE_FILES_FULL_INSTALL_DIR)/,$(RESOURCE_FILES)) \
   internal-resource-set-install-languages

ifeq ($(LOCALIZED_RESOURCE_FILES),)
internal-resource-set-install-languages:

else

# Rule to build the language installation directories
$(addsuffix .lproj,$(addprefix $(RESOURCE_FILES_FULL_INSTALL_DIR)/,$(LANGUAGES))):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

# install the localized resources, checking the installation date by
# using test -nt ... this doesn't seem to be easy to do using make
# rules because we want to issue a warning if the directory/file can't
# be found, rather than aborting with an error as make would do.
internal-resource-set-install-languages: \
$(addsuffix .lproj,$(addprefix $(RESOURCE_FILES_FULL_INSTALL_DIR)/,$(LANGUAGES)))
	$(ECHO_NOTHING)for l in $(LANGUAGES); do \
	  if [ -d $$l.lproj ]; then \
	    for f in $(LOCALIZED_RESOURCE_FILES); do \
	      if [ -f $$l.lproj/$$f ]; then \
	        if [ $$l.lproj -nt $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$l.lproj/$$f ]; then \
	        $(INSTALL_DATA) $$l.lproj/$$f \
	                        $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$l.lproj; \
	        fi; \
	      else \
	        echo "Warning: $$l.lproj/$$f not found - ignoring"; \
	      fi; \
	    done; \
	  else \
	    echo "Warning: $$l.lproj not found - ignoring"; \
	  fi; \
	done$(END_ECHO)


endif # LOCALIZED_RESOURCE_FILES

endif


internal-resource_set-uninstall_:
ifneq ($(LOCALIZED_RESOURCE_FILES),)
	-$(ECHO_NOTHING)for language in $(LANGUAGES); do \
	  for file in $(LOCALIZED_RESOURCE_FILES); do \
	    rm -rf $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$language.lproj/$$file;\
	  done; \
	  rmdir $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$language.lproj; \
	done$(END_ECHO)
endif
ifneq ($(RESOURCE_FILES),)
	$(ECHO_NOTHING)for file in $(RESOURCE_FILES); do \
	  rm -rf $(RESOURCE_FILES_FULL_INSTALL_DIR)/$$file ; \
	done$(END_ECHO)
	-rmdir $(RESOURCE_FILES_FULL_INSTALL_DIR)
endif
