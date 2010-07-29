#
#   Shared/headers.make
#
#   Makefile fragment with rules to install header files
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

#
# input variables:
#
#  $(GNUSTEP_INSTANCE)_HEADER_FILES : the list of .h files to install
#
#  $(GNUSTEP_INSTANCE)_HEADER_FILES_DIR : the dir in which the .h files are;
#  defaults to `.' if no set.
#
#  $(GNUSTEP_INSTANCE)_HEADER_FILES_INSTALL_DIR : the dir in which to install
#  the .h files; defaults to $(GNUSTEP_INSTANCE) if not set.  Please set it 
#  to `.' if you want it to be like empty.
#

#
# public targets:
# 
#  shared-instance-headers-install 
#  shared-instance-headers-uninstall
#

HEADER_FILES = $($(GNUSTEP_INSTANCE)_HEADER_FILES)

.PHONY: \
shared-instance-headers-install \
shared-instance-headers-uninstall

# We always compute HEADER_FILES_DIR and HEADER_FILES_INSTALL_DIR.
# The reason is that frameworks might have headers in subprojects (and
# not in the top framework makefile!).  Those headers are
# automatically used and installed, but in the top-level makefile,
# HEADER_FILES = '', still you might want to have a special
# HEADER_FILES_DIR and HEADER_FILES_INSTALL_DIR even in this case.
# NB: Header installation for frameworks is done by the framework
# code.
HEADER_FILES_DIR = $($(GNUSTEP_INSTANCE)_HEADER_FILES_DIR)

ifeq ($(HEADER_FILES_DIR),)
  HEADER_FILES_DIR = .
endif

HEADER_FILES_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_HEADER_FILES_INSTALL_DIR)

# Please use `.' to force it to stay empty
ifeq ($(HEADER_FILES_INSTALL_DIR),)
  HEADER_FILES_INSTALL_DIR = $(GNUSTEP_INSTANCE)
endif

ifeq ($(HEADER_FILES),)

shared-instance-headers-install:

shared-instance-headers-uninstall:

shared-instance-headers-all:

else # we have some HEADER_FILES

#
# We provide two different algorithms of installing headers.
#

ifeq ($(GNUSTEP_DEVELOPER),)

# 
# The first one is the standard one.  We run a subshell, loop on all the
# header files, and install all of them.  This is the default one.
#

shared-instance-headers-install: $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)
	$(ECHO_INSTALLING_HEADERS)for file in $(HEADER_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $(HEADER_FILES_DIR)/$$file \
	          $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)/$$file; \
	  fi; \
	done$(END_ECHO)

else

# 
# The second one (which you activate by setting GNUSTEP_DEVELOPER to
# YES in your shell) is the one specifically optimized for faster
# development.  We only install headers which are newer than the
# installed version.  This is much faster if you are developing and
# need to install headers often, and normally with just few changes.
# It is slower the first time you install the headers, because we
# install them using a lot of subshell processes (which is why it is not
# the default - `users' install headers only once - the default
# setup is for users).
#

shared-instance-headers-install: \
  $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR) \
  $(addprefix $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)/,$(HEADER_FILES))

$(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)/% : $(HEADER_FILES_DIR)/%
	$(ECHO_NOTHING)$(INSTALL_DATA) $< $@$(END_ECHO)

endif

$(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)


shared-instance-headers-uninstall:
	$(ECHO_NOTHING)for file in $(HEADER_FILES) __done; do \
	  if [ $$file != __done ]; then \
	    rm -rf $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)/$$file ; \
	  fi; \
	done$(END_ECHO)

# TODO - during uninstall, it would be pretty to remove
# $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR) if it's empty.

endif # HEADER_FILES = ''
