#
#   Instance/service.make
#
#   Instance Makefile rules to build GNUstep-based services.
#
#   Copyright (C) 1998, 2001 Free Software Foundation, Inc.
#
#   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
#   Based on the makefiles by Scott Christley.
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
# The name of the service is in the SERVICE_NAME variable.
# The NSServices info should be in $(SERVICE_NAME)Info.plist
# The list of service resource file are in xxx_RESOURCE_FILES
# The list of service resource directories are in xxx_RESOURCE_DIRS
# where xxx is the service name
#

.PHONY: internal-service-all_ \
        internal-service-install_ \
        internal-service-uninstall_ \
        internal-service-copy_into_dir \
        service-resource-files

# Libraries that go before the GUI libraries
ALL_SERVICE_LIBS =							\
    $(shell $(WHICH_LIB_SCRIPT)						\
	$(ALL_LIB_DIRS)							\
	$(ADDITIONAL_GUI_LIBS) $(AUXILIARY_GUI_LIBS)			\
	$(GUI_LIBS) $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS)	\
	$(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS)	\
	$(OBJC_LIBS) $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)		\
	debug=$(debug) profile=$(profile) shared=$(shared)		\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

# Don't include these definitions the first time make is invoked. This part is
# included when make is invoked the second time from the %.build rule (see
# rules.make).
SERVICE_DIR_NAME = $(GNUSTEP_INSTANCE:=.service)
SERVICE_DIR = $(GNUSTEP_BUILD_DIR)/$(SERVICE_DIR_NAME)

#
# Internal targets
#
SERVICE_FILE_NAME = $(SERVICE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE)
SERVICE_FILE = $(GNUSTEP_BUILD_DIR)/$(SERVICE_FILE_NAME)

ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  SERVICE_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(SERVICE_INSTALL_DIR),)
  SERVICE_INSTALL_DIR = $(GNUSTEP_SERVICES)
endif

GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(SERVICE_DIR)/Resources
GNUSTEP_SHARED_BUNDLE_MAIN_PATH = $(SERVICE_DIR_NAME)
GNUSTEP_SHARED_BUNDLE_INSTALL_DIR = $(SERVICE_INSTALL_DIR)
include $(GNUSTEP_MAKEFILES)/Instance/Shared/bundle.make

internal-service-all_:: $(GNUSTEP_OBJ_DIR) \
                        $(SERVICE_DIR)/$(GNUSTEP_TARGET_LDIR) \
                        $(SERVICE_FILE) \
                        $(SERVICE_DIR)/Resources/Info-gnustep.plist \
                        shared-instance-bundle-all

$(SERVICE_FILE): $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING)$(LD) $(ALL_LDFLAGS) $(CC_LDFLAGS) -o $(LDOUT)$@ \
	$(OBJ_FILES_TO_LINK) $(ALL_SERVICE_LIBS)$(END_ECHO)

$(SERVICE_DIR)/$(GNUSTEP_TARGET_LDIR):
	$(ECHO_CREATING)$(MKDIRS) $(SERVICE_DIR)/$(GNUSTEP_TARGET_LDIR)$(END_ECHO)


# Allow the gui library to redefine make_services to use its local one
ifeq ($(GNUSTEP_MAKE_SERVICES),)
  GNUSTEP_MAKE_SERVICES = make_services
endif

$(SERVICE_DIR)/Resources/Info-gnustep.plist: \
	$(SERVICE_DIR)/Resources $(GNUSTEP_INSTANCE)Info.plist 
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)\";"; \
	  cat $(GNUSTEP_INSTANCE)Info.plist; \
	  echo "}") >$@ ;\
	if $(GNUSTEP_MAKE_SERVICES) --test $@; then : ; else rm -f $@; false; \
	fi$(END_ECHO)

internal-service-copy_into_dir:: shared-instance-bundle-copy_into_dir

#
# Install targets
#
$(SERVICE_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-service-install_:: shared-instance-bundle-install
ifeq ($(strip),yes)
	$(ECHO_STRIPPING)$(STRIP) $(SERVICE_INSTALL_DIR)/$(SERVICE_FILE_NAME)$(END_ECHO)
endif

internal-service-uninstall_:: shared-instance-bundle-uninstall

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make
