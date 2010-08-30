#
#   wobundle.make
#
#   Makefile rules to build GNUstep web bundles.
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
#   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

ifeq ($(GNUSTEP_INSTANCE),)
ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

ifeq ($(strip $(WOBUNDLE_EXTENSION)),)
WOBUNDLE_EXTENSION = .wobundle
endif

WOBUNDLE_NAME := $(strip $(WOBUNDLE_NAME))

internal-all:: $(WOBUNDLE_NAME:=.all.wobundle.variables)

internal-install:: $(WOBUNDLE_NAME:=.install.wobundle.variables)

internal-uninstall:: $(WOBUNDLE_NAME:=.uninstall.wobundle.variables)

internal-clean:: $(WOBUNDLE_NAME:=.clean.wobundle.subprojects)
	rm -rf $(GNUSTEP_OBJ_DIR) \
	       $(addsuffix $(WOBUNDLE_EXTENSION),$(WOBUNDLE_NAME))

internal-distclean:: $(WOBUNDLE_NAME:=.distclean.wobundle.subprojects)
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj

$(WOBUNDLE_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
		$@.all.wobundle.variables
else

ifeq ($(GNUSTEP_TYPE),wobundle)
ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

# FIXME - this file has not been updated to use Shared/bundle.make
# because it is using symlinks rather than copying resources.

COMPONENTS = $($(GNUSTEP_INSTANCE)_COMPONENTS)
LANGUAGES = $($(GNUSTEP_INSTANCE)_LANGUAGES)
WEBSERVER_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_WEBSERVER_RESOURCE_FILES)
LOCALIZED_WEBSERVER_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_LOCALIZED_WEBSERVER_RESOURCE_FILES)
WEBSERVER_RESOURCE_DIRS = $($(GNUSTEP_INSTANCE)_WEBSERVER_RESOURCE_DIRS)
LOCALIZED_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_LOCALIZED_RESOURCE_FILES)
RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_RESOURCE_FILES)
RESOURCE_DIRS = $($(GNUSTEP_INSTANCE)_RESOURCE_DIRS)

include $(GNUSTEP_MAKEFILES)/Instance/Shared/headers.make

ifeq ($(strip $(WOBUNDLE_EXTENSION)),)
WOBUNDLE_EXTENSION = .wobundle
endif

WOBUNDLE_LD = $(BUNDLE_LD)
WOBUNDLE_LDFLAGS = $(BUNDLE_LDFLAGS)

ifeq ($(FOUNDATION_LIB),apple)
WORSRCDIRINFIX:=Contents/Resources
WORSRCLINKUP:=../../..
else
WORSRCDIRINFIX:=Resources
WORSRCLINKUP:=../..
endif

ifeq ($(WOBUNDLE_INSTALL_DIR),)
WOBUNDLE_INSTALL_DIR = $(GNUSTEP_WEB_APPS)
endif
# The name of the bundle is in the BUNDLE_NAME variable.
# The list of languages the bundle is localized in are in xxx_LANGUAGES
# The list of bundle resource file are in xxx_RESOURCE_FILES
# The list of localized bundle resource file are in xxx_LOCALIZED_RESOURCE_FILES
# The list of bundle resource directories are in xxx_RESOURCE_DIRS
# The name of the principal class is xxx_PRINCIPAL_CLASS
# The header files are in xxx_HEADER_FILES
# The directory where the header files are located is xxx_HEADER_FILES_DIR
# The directory where to install the header files inside the library
# installation directory is xxx_HEADER_FILES_INSTALL_DIR
# where xxx is the bundle name
#  xxx_WEBSERVER_RESOURCE_DIRS <==
# The list of localized application web server resource directories are in 
#  xxx_LOCALIZED_WEBSERVER_RESOURCE_DIRS
# where xxx is the application name <==

.PHONY: internal-wobundle-all_ \
        internal-wobundle-install_ \
        internal-wobundle-uninstall_ \
        build-bundle-dir \
        build-bundle \
        wobundle-components \
        wobundle-resource-files \
        wobundle-localized-resource-files \
        wobundle-webresource-dir \
        wobundle-webresource-files \
        wobundle-localized-webresource-files

# On Solaris we don't need to specifies the libraries the bundle needs.
# How about the rest of the systems? ALL_BUNDLE_LIBS is temporary empty.
TALL_WOBUNDLE_LIBS = $(ADDITIONAL_WO_LIBS) $(AUXILIARY_WO_LIBS) $(WO_LIBS) \
	$(ADDITIONAL_BUNDLE_LIBS) $(AUXILIARY_BUNDLE_LIBS) \
	$(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) \
	$(OBJC_LIBS) $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)
#ALL_WOBUNDLE_LIBS = 
ifeq ($(WHICH_LIB_SCRIPT),)
ALL_WOBUNDLE_LIBS = $(ALL_LIB_DIRS) $(TALL_WOBUNDLE_LIBS)
else
ALL_WOBUNDLE_LIBS = \
    $(shell $(WHICH_LIB_SCRIPT) $(ALL_LIB_DIRS) $(TALL_WOBUNDLE_LIBS) \
	debug=$(debug) profile=$(profile) shared=$(shared) libext=$(LIBEXT) \
	shared_libext=$(SHARED_LIBEXT))
endif

# order is important
# GNUSTEP_OBJ_INSTANCE_DIR, OBJ_DIRS_TO_CREATE required for gnustep-make >= 2.2
# GNUSTEP_OBJ_DIR required for gnustep-make < 2.2
internal-wobundle-all_:: $(GNUSTEP_OBJ_INSTANCE_DIR) \
                          $(OBJ_DIRS_TO_CREATE) \
                          $(GNUSTEP_OBJ_DIR) \
                          build-bundle-dir \
                          build-bundle

WOBUNDLE_DIR_NAME = $(GNUSTEP_INSTANCE:=$(WOBUNDLE_EXTENSION))
WOBUNDLE_FILE = \
    $(WOBUNDLE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE)
WOBUNDLE_RESOURCE_DIRS = $(foreach d, $(RESOURCE_DIRS), $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX)/$(d))
WOBUNDLE_WEBSERVER_RESOURCE_DIRS =  $(foreach d, $(WEBSERVER_RESOURCE_DIRS), $(WOBUNDLE_DIR_NAME)/Resources/WebServer/$(d))

ifeq ($(strip $(LANGUAGES)),)
  LANGUAGES="English"
endif


build-bundle-dir:: $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX) \
                   $(WOBUNDLE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR) \
                   $(WOBUNDLE_RESOURCE_DIRS)

$(WOBUNDLE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR):
	@$(MKDIRS) $(WOBUNDLE_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)

$(WOBUNDLE_RESOURCE_DIRS):
	@$(MKDIRS) $(WOBUNDLE_RESOURCE_DIRS)

build-bundle:: $(WOBUNDLE_FILE) \
               wobundle-components \
               wobundle-resource-files \
               wobundle-localized-resource-files \
               wobundle-localized-webresource-files \
               wobundle-webresource-files


$(WOBUNDLE_FILE) : $(OBJ_FILES_TO_LINK)
	$(WOBUNDLE_LD) $(WOBUNDLE_LDFLAGS) \
	                $(ALL_LDFLAGS) -o $(LDOUT)$(WOBUNDLE_FILE) \
			$(OBJ_FILES_TO_LINK) \
	                $(ALL_WOBUNDLE_LIBS)

wobundle-components :: $(WOBUNDLE_DIR_NAME)
ifneq ($(strip $(COMPONENTS)),)
	@(echo "Linking components into the bundle wrapper..."; \
        cd $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX); \
        for component in $(COMPONENTS); do \
	  if [ -d $(WORSRCLINKUP)/$$component ]; then \
	    $(LN_S) -f $(WORSRCLINKUP)/$$component ./;\
	  fi; \
        done; \
	echo "Linking localized components into the bundle wrapper..."; \
        for l in $(LANGUAGES); do \
	  if [ -d $(WORSRCLINKUP)/$$l.lproj ]; then \
	    $(MKDIRS) $$l.lproj; \
	    cd $$l.lproj; \
	    for f in $(COMPONENTS); do \
	      if [ -d $(WORSRCLINKUP)/../$$l.lproj/$$f ]; then \
	        $(LN_S) -f $(WORSRCLINKUP)/../$$l.lproj/$$f .;\
	      fi;\
	    done;\
	    cd ..; \
	  fi;\
	done)
endif

wobundle-resource-files:: $(WOBUNDLE_DIR_NAME)/bundle-info.plist \
                           $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX)/Info-gnustep.plist
ifneq ($(strip $(RESOURCE_FILES)),)
	@(echo "Linking resources into the bundle wrapper..."; \
	cd $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX)/; \
	for ff in $(RESOURCE_FILES); do \
	  $(LN_S) -f $(WORSRCLINKUP)/$$ff .;\
	done)
endif

wobundle-localized-resource-files:: $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX)/Info-gnustep.plist
ifneq ($(strip $(LOCALIZED_RESOURCE_FILES)),)
	@(echo "Linking localized resources into the bundle wrapper..."; \
	cd $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX); \
	for l in $(LANGUAGES); do \
	  if [ -d $(WORSRCLINKUP)/$$l.lproj ]; then \
	    $(MKDIRS) $$l.lproj; \
	    cd $$l.lproj; \
	    for f in $(LOCALIZED_RESOURCE_FILES); do \
	      if [ -f $(WORSRCLINKUP)/../$$l.lproj/$$f ]; then \
	        $(LN_S) -f $(WORSRCLINKUP)/../$$l.lproj/$$f .;\
	      fi;\
	    done;\
	    cd ..;\
	  else\
	   echo "Warning - $$l.lproj not found - ignoring";\
	  fi;\
	done)
endif

wobundle-webresource-dir::
	@$(MKDIRS) $(WOBUNDLE_WEBSERVER_RESOURCE_DIRS)

wobundle-webresource-files:: $(WOBUNDLE_DIR_NAME)/Resources/WebServer \
                              wobundle-webresource-dir
ifneq ($(strip $(WEBSERVER_RESOURCE_FILES)),)
	@(echo "Linking webserver resources into the application wrapper..."; \
	cd $(WOBUNDLE_DIR_NAME)/Resources/WebServer; \
	for ff in $(WEBSERVER_RESOURCE_FILES); do \
	  $(LN_S) -f ../../WebServerResources/$$ff .;\
	done)
endif

wobundle-localized-webresource-files:: $(WOBUNDLE_DIR_NAME)/Resources/WebServer \
                                        wobundle-webresource-dir
ifneq ($(strip $(LOCALIZED_WEBSERVER_RESOURCE_FILES)),)
	@(echo "Linking localized web resources into the application wrapper..."; \
	cd $(WOBUNDLE_DIR_NAME)/Resources/WebServer; \
	for l in $(LANGUAGES); do \
	  if [ -d ../../WebServerResources/$$l.lproj ]; then \
	    $(MKDIRS) $$l.lproj; \
	    cd $$l.lproj; \
	    for f in $(LOCALIZED_WEBSERVER_RESOURCE_FILES); do \
	      if [ -f ../../../WebServerResources/$$l.lproj/$$f ]; then \
	        if [ ! -r $$f ]; then \
	          $(LN_S) ../../../WebServerResources/$$l.lproj/$$f $$f;\
	        fi;\
	      fi;\
	    done;\
	    cd ..; \
	  else \
	    echo "Warning - WebServerResources/$$l.lproj not found - ignoring";\
	  fi;\
	done)
endif

PRINCIPAL_CLASS = $(strip $($(GNUSTEP_INSTANCE)_PRINCIPAL_CLASS))

ifeq ($(PRINCIPAL_CLASS),)
  PRINCIPAL_CLASS = $(GNUSTEP_INSTANCE)
endif

$(WOBUNDLE_DIR_NAME)/bundle-info.plist: $(WOBUNDLE_DIR_NAME)
	@(cd $(WOBUNDLE_DIR_NAME); $(LN_S) -f ../bundle-info.plist .)

HAS_WOCOMPONENTS = $($(GNUSTEP_INSTANCE)_HAS_WOCOMPONENTS)

$(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX)/Info-gnustep.plist: $(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX)
	@(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)\";"; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  if [ "$(HAS_WOCOMPONENTS)" != "" ]; then \
	    echo "  HasWOComponents = \"$(HAS_WOCOMPONENTS)\";"; \
	  fi; \
	  echo "}") >$@

$(WOBUNDLE_DIR_NAME)/$(WORSRCDIRINFIX):
	@$(MKDIRS) $@

$(WOBUNDLE_DIR_NAME)/Resources/WebServer:
	@$(MKDIRS) $@

internal-wobundle-install_:: $(WOBUNDLE_INSTALL_DIR) shared-instance-headers-install
#	rm -rf $(WOBUNDLE_INSTALL_DIR)/$(WOBUNDLE_DIR_NAME); \
#	$(TAR) chf - --exclude=CVS --exclude=.svn --to-stdout $(WOBUNDLE_DIR_NAME) | (cd $(WOBUNDLE_INSTALL_DIR); $(TAR) xf -)
	if [ -e $(WOBUNDLE_INSTALL_DIR)/$(WOBUNDLE_DIR_NAME) ]; then rm -rf $(WOBUNDLE_INSTALL_DIR)/$(WOBUNDLE_DIR_NAME); fi; \
	cp -LR $(WOBUNDLE_DIR_NAME) $(WOBUNDLE_INSTALL_DIR)
ifneq ($(CHOWN_TO),)
	$(CHOWN) -R $(CHOWN_TO) $(WOBUNDLE_INSTALL_DIR)/$(WOBUNDLE_DIR_NAME)
endif
ifeq ($(strip),yes)
	$(STRIP) $(WOBUNDLE_INSTALL_DIR)/$(WOBUNDLE_FILE) 
endif

$(WOBUNDLE_INSTALL_DIR)::
	@$(MKINSTALLDIRS) $@

internal-wobundle-uninstall_:: shared-instance-headers-uninstall
	rm -rf $(WOBUNDLE_INSTALL_DIR)/$(WOBUNDLE_DIR_NAME)
endif

endif

## Local variables:
## mode: makefile
## End:
