#
#   Shared/java.make
#
#   Makefile fragment with rules to compile and install java files,
#   with associated property files.
#
#   Copyright (C) 2000, 2002 Free Software Foundation, Inc.
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

#
# input variables:
#
#  JAVA_OBJ_FILES, JAVA_JNI_OBJ_FILES, SUBPROJECT_OBJ_FILES :
#  the list of object files (built by Instance/rules.make)
#
#  $(GNUSTEP_INSTANCE)_JAVA_PROPERTIES_FILES : the list of .properties files
#  to install together with the .java files
#
#  GNUSTEP_SHARED_JAVA_INSTALLATION_DIR : the base directory where to
#  install the files.
#

#
# public targets:
# 
#  shared-instance-java-all 
#  shared-instance-java-install
#  shared-instance-java-uninstall
#  shared-instance-java-clean
#


.PHONY: \
shared-instance-java-all \
shared-instance-java-install \
shared-instance-java-install-dirs \
shared-instance-java-uninstall \
shared-instance-java-clean


shared-instance-java-all: $(JAVA_OBJ_FILES) \
                         $(JAVA_JNI_OBJ_FILES) \
                         $(SUBPROJECT_OBJ_FILES)

# Say that you have a Pisa.java source file.  Here we install both
# Pisa.class (the main class) and also, if they exist, all class files
# with names beginning wih Pisa$ (such as Pisa$1$Nicola.class); these
# files are generated for nested/inner classes, and must be installed
# as well.  The fact we need to install these files is the reason why
# the following is more complicated than you would think at first
# glance.

# Build efficiently the list of possible inner/nested classes 

# We first build a list like in `Pisa[$]*.class Roma[$]*.class' by
# taking the JAVA_OBJ_FILES and replacing .class with [$]*.class, then
# we use wildcard to get the list of all files matching the pattern
UNESCAPED_ADD_JAVA_OBJ_FILES = $(wildcard $(JAVA_OBJ_FILES:.class=[$$]*.class))

# Finally we need to escape the $s before passing the filenames to the
# shell
ADDITIONAL_JAVA_OBJ_FILES = $(subst $$,\$$,$(UNESCAPED_ADD_JAVA_OBJ_FILES))

JAVA_PROPERTIES_FILES = $($(GNUSTEP_INSTANCE)_JAVA_PROPERTIES_FILES)

shared-instance-java-install: shared-instance-java-install-dirs
ifneq ($(JAVA_OBJ_FILES),)
	$(ECHO_INSTALLING_CLASS_FILES)for file in $(JAVA_OBJ_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $$file \
	                    $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)
endif
ifneq ($(ADDITIONAL_JAVA_OBJ_FILES),)
	$(ECHO_INSTALLING_ADD_CLASS_FILES)for file in $(ADDITIONAL_JAVA_OBJ_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $$file \
	                    $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)
endif
ifneq ($(JAVA_PROPERTIES_FILES),)
	$(ECHO_INSTALLING_PROPERTIES_FILES)for file in $(JAVA_PROPERTIES_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $$file \
	                    $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)
endif

shared-instance-java-install-dirs: $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)
ifneq ($(JAVA_OBJ_FILES),)
	$(ECHO_NOTHING)$(MKINSTALLDIRS) \
           $(addprefix $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/,$(dir $(JAVA_OBJ_FILES)))$(END_ECHO)
endif

$(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

shared-instance-java-clean:
	$(ECHO_NOTHING)rm -f $(JAVA_OBJ_FILES) \
	      $(ADDITIONAL_JAVA_OBJ_FILES) \
	      $(JAVA_JNI_OBJ_FILES)$(END_ECHO)

shared-instance-java-uninstall:
ifneq ($(JAVA_OBJ_FILES),)
	$(ECHO_NOTHING)for file in $(JAVA_OBJ_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    rm -f $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)
endif
ifneq ($(ADDITIONAL_JAVA_OBJ_FILES),)
	$(ECHO_NOTHING)for file in $(ADDITIONAL_JAVA_OBJ_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    rm -f $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)
endif
ifneq ($(JAVA_PROPERTIES_FILES),)
	$(ECHO_NOTHING)for file in $(JAVA_PROPERTIES_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    rm -f $(GNUSTEP_SHARED_JAVA_INSTALLATION_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)
endif
