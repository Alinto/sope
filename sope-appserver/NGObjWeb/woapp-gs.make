#
#   woapp.make
#
#   Makefile rules to build GNUstep web based applications.
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

# Determine the application directory extension
WOAPP_EXTENSION=woa

WOAPP_NAME := $(strip $(WOAPP_NAME))

internal-all:: $(WOAPP_NAME:=.all.woapp.variables)

internal-install:: $(WOAPP_NAME:=.install.woapp.variables)

internal-uninstall:: $(WOAPP_NAME:=.uninstall.woapp.variables)

internal-clean:: $(WOAPP_NAME:=.clean.woapp.subprojects)
	rm -rf $(GNUSTEP_OBJ_DIR)
ifeq ($(OBJC_COMPILER), NeXT)
	rm -f *.iconheader
	for f in *.$(WOAPP_EXTENSION); do \
	  rm -f $$f/`basename $$f .$(WOAPP_EXTENSION)`; \
	done
else
ifeq ($(GNUSTEP_FLATTENED),)
	rm -rf *.$(WOAPP_EXTENSION)/$(GNUSTEP_TARGET_LDIR)
else
	rm -rf *.$(WOAPP_EXTENSION)
endif
endif

internal-distclean:: $(WOAPP_NAME:=.distclean.woapp.subprojects)
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj *.woa *.debug *.profile *.iconheader

$(WOAPP_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory \
	            $@.all.woapp.variables
else

ifeq ($(GNUSTEP_TYPE),woapp)
ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

# FIXME/TODO - this file has not been updated to use
# Instance/Shared/bundle.make because it is linking resources instead of
# copying them.


#
# The name of the application is in the WOAPP_NAME variable.
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

COMPONENTS = $($(GNUSTEP_INSTANCE)_COMPONENTS)
LANGUAGES = $($(GNUSTEP_INSTANCE)_LANGUAGES)
WEBSERVER_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_WEBSERVER_RESOURCE_FILES)
LOCALIZED_WEBSERVER_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_LOCALIZED_WEBSERVER_RESOURCE_FILES)
WEBSERVER_RESOURCE_DIRS = $($(GNUSTEP_INSTANCE)_WEBSERVER_RESOURCE_DIRS)
LOCALIZED_RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_LOCALIZED_RESOURCE_FILES)
RESOURCE_FILES = $($(GNUSTEP_INSTANCE)_RESOURCE_FILES)
RESOURCE_DIRS = $($(GNUSTEP_INSTANCE)_RESOURCE_DIRS)

ifeq ($(FOUNDATION_LIB),apple)
WORSRCDIRINFIX:=Contents/Resources
WORSRCLINKUP:=../../..
else
WORSRCDIRINFIX:=Resources
WORSRCLINKUP:=../..
endif

# Determine the application directory extension
WOAPP_EXTENSION = woa

GNUSTEP_WOAPPS = $(GNUSTEP_WEB_APPS)

.PHONY: internal-woapp-all_ \
        internal-woapp-install_ \
        internal-woapp-uninstall_ \
        woapp-components \
        woapp-webresource-dir \
        woapp-webresource-files \
        woapp-localized-webresource-files \
        woapp-resource-dir \
        woapp-resource-files \
        woapp-localized-resource-files

# Libraries that go before the WO libraries
ifndef WHICH_LIB_SCRIPT
ALL_WO_LIBS =								\
	$(ALL_LIB_DIRS)							\
	$(ADDITIONAL_WO_LIBS) $(AUXILIARY_WO_LIBS) $(WO_LIBS)	\
	$(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS)			\
	$(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS)	\
        $(OBJC_LIBS) $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)
else
ALL_WO_LIBS =								\
    $(shell $(WHICH_LIB_SCRIPT)						\
	$(ALL_LIB_DIRS)							\
	$(ADDITIONAL_WO_LIBS) $(AUXILIARY_WO_LIBS) $(WO_LIBS)	\
	$(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS)			\
	$(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS)	\
        $(OBJC_LIBS) $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)		\
	debug=$(debug) profile=$(profile) shared=$(shared)		\
	libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))
endif

# Don't include these definitions the first time make is invoked. This part is
# included when make is invoked the second time from the %.build rule (see
# rules.make).
WOAPP_DIR_NAME = $(GNUSTEP_INSTANCE:=.$(WOAPP_EXTENSION))
WOAPP_RESOURCE_DIRS =  $(foreach d, $(RESOURCE_DIRS), $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX)/$(d))
WOAPP_WEBSERVER_RESOURCE_DIRS =  $(foreach d, $(WEBSERVER_RESOURCE_DIRS), $(WOAPP_DIR_NAME)/WebServerResources/$(d))
ifeq ($(strip $(LANGUAGES)),)
  LANGUAGES="English"
endif

# Support building NeXT applications
ifneq ($(OBJC_COMPILER), NeXT)
WOAPP_FILE = \
    $(WOAPP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE)$(EXEEXT)
else
WOAPP_FILE = $(WOAPP_DIR_NAME)/$(GNUSTEP_INSTANCE)$(EXEEXT)
endif

#
# Internal targets
#

$(WOAPP_FILE): $(OBJ_FILES_TO_LINK)
	$(LD) $(ALL_LDFLAGS) -o $(LDOUT)$@ $(OBJ_FILES_TO_LINK) \
	      $(ALL_WO_LIBS)

ifeq ($(OBJC_COMPILER), NeXT)
	@$(TRANSFORM_PATHS_SCRIPT) $(subst -L,,$(ALL_LIB_DIRS)) \
		>$(WOAPP_DIR_NAME)/library_paths.openapp
# This is a hack for OPENSTEP systems to remove the iconheader file
# automatically generated by the makefile package.
	rm -f $(GNUSTEP_INSTANCE).iconheader
else
	@$(TRANSFORM_PATHS_SCRIPT) $(subst -L,,$(ALL_LIB_DIRS)) \
	>$(WOAPP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/library_paths.openapp
endif

#
# Compilation targets
#
ifeq ($(OBJC_COMPILER), NeXT)
internal-woapp-all_:: \
	$(GNUSTEP_OBJ_DIR) $(WOAPP_DIR_NAME) $(WOAPP_FILE) \
	woapp-components \
	woapp-localized-webresource-files \
	woapp-webresource-files \
	woapp-localized-resource-files \
	woapp-resource-files \
	$(WOAPP_DIR_NAME)/$(GNUSTEP_INSTANCE).sh

$(GNUSTEP_INSTANCE).iconheader:
	@(echo "F	$(GNUSTEP_INSTANCE).$(WOAPP_EXTENSION)	$(GNUSTEP_INSTANCE)	$(WOAPP_EXTENSION)"; \
	  echo "F	$(GNUSTEP_INSTANCE)	$(GNUSTEP_INSTANCE)	app") >$@

$(WOAPP_DIR_NAME):
	mkdir $@
else

internal-woapp-all_:: \
   $(GNUSTEP_OBJ_DIR) \
   $(WOAPP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR) $(WOAPP_FILE) \
   woapp-components \
   woapp-localized-webresource-files \
   woapp-webresource-files \
   woapp-localized-resource-files \
   woapp-resource-files \
   $(WOAPP_DIR_NAME)/$(GNUSTEP_INSTANCE).sh

$(WOAPP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR):
	@$(MKDIRS) $(WOAPP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)
endif

ifeq ($(GNUSTEP_INSTANCE)_GEN_SCRIPT,yes) #<==
$(WOAPP_DIR_NAME)/$(GNUSTEP_INSTANCE).sh: $(WOAPP_DIR_NAME)
	@(echo "#!/bin/sh"; \
	  echo '# Automatically generated, do not edit!'; \
	  echo '$${GNUSTEP_HOST_LDIR}/$(GNUSTEP_INSTANCE) $$1 $$2 $$3 $$4 $$5 $$6 $$7 $$8') >$@
	chmod +x $@
else
$(WOAPP_DIR_NAME)/$(GNUSTEP_INSTANCE).sh:

endif

woapp-components:: $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX)
ifneq ($(strip $(COMPONENTS)),)
	@ echo "Linking components into the application wrapper..."; \
        cd $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX); \
        for component in $(COMPONENTS); do \
	  if [ -d $(WORSRCLINKUP)/$$component ]; then \
	     $(LN_S) -f $(WORSRCLINKUP)/$$component ./;\
	  fi; \
        done; \
	echo "Linking localized components into the application wrapper..."; \
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
	done
endif

# FIXME - this is behaving differently than in wobundle.make !
# It's also not behaving consistently with xxx_RESOURCE_DIRS
woapp-webresource-dir:: $(WOAPP_WEBSERVER_RESOURCE_DIRS)
ifneq ($(strip $(WEBSERVER_RESOURCE_DIRS)),)
	@ echo "Linking webserver Resource Dirs into the application wrapper..."; \
        cd $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX); \
        for dir in $(WEBSERVER_RESOURCE_DIRS); do \
	  if [ -d $(WORSRCLINKUP)/$$dir ]; then \
	     $(LN_S) -f $(WORSRCLINKUP)/$$dir ./;\
	  fi; \
        done;
endif

$(WOAPP_WEBSERVER_RESOURCE_DIRS):
	#@$(MKDIRS) $(WOAPP_WEBSERVER_RESOURCE_DIRS)

woapp-webresource-files:: $(WOAPP_DIR_NAME)/WebServerResources \
                           woapp-webresource-dir
ifneq ($(strip $(WEBSERVER_RESOURCE_FILES)),)
	@echo "Linking webserver resources into the application wrapper..."; \
        cd $(WOAPP_DIR_NAME)/WebServerResources; \
        for ff in $(WEBSERVER_RESOURCE_FILES); do \
	  $(LN_S) -f ../../$$ff .;\
        done
endif

woapp-localized-webresource-files:: $(WOAPP_DIR_NAME)/WebServerResources woapp-webresource-dir
ifneq ($(strip $(LOCALIZED_WEBSERVER_RESOURCE_FILES)),)
	@ echo "Linking localized web resources into the application wrapper..."; \
	cd $(WOAPP_DIR_NAME)/WebServerResources; \
	for l in $(LANGUAGES); do \
	  if [ -d ../../WebServerResources/$$l.lproj ]; then \
	    $(MKDIRS) $$l.lproj;\
	    cd $$l.lproj; \
	    for f in $(LOCALIZED_WEBSERVER_RESOURCE_FILES); do \
	      if [ -f ../../../$$l.lproj/$$f ]; then \
	        if [ ! -r $$f ]; then \
	          $(LN_S) ../../../$$l.lproj/$$f $$f;\
	        fi;\
	      fi;\
	    done;\
	    cd ..; \
	  else\
	   echo "Warning - WebServerResources/$$l.lproj not found - ignoring";\
	  fi;\
	done
endif

# This is not consistent with what other projects do ... so it can't stay
# this way.  Use COMPONENTS instead.
woapp-resource-dir:: $(WOAPP_RESOURCE_DIRS)
ifneq ($(strip $(RESOURCE_DIRS)),)
	@ echo "Linking Resource Dirs into the application wrapper..."; \
        cd $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX); \
        for dir in $(RESOURCE_DIRS); do \
	  if [ -d $(WORSRCLINKUP)/$$dir ]; then \
	     $(LN_S) -f $(WORSRCLINKUP)/$$dir ./;\
	  fi; \
        done;
endif

$(WOAPP_RESOURCE_DIRS):
	#@$(MKDIRS) $(WOAPP_RESOURCE_DIRS)

woapp-resource-files:: $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX)/Info-gnustep.plist \
                        woapp-resource-dir
ifneq ($(strip $(RESOURCE_FILES)),)
	@ echo "Linking resources into the application wrapper..."; \
        cd $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX)/; \
        for ff in $(RESOURCE_FILES); do \
	  $(LN_S) -f $(WORSRCLINKUP)/$$ff .;\
        done
endif

woapp-localized-resource-files:: $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX) \
                                  woapp-resource-dir
ifneq ($(strip $(LOCALIZED_RESOURCE_FILES)),)
	@ echo "Linking localized resources into the application wrapper..."; \
        cd $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX); \
        for l in $(LANGUAGES); do \
	  if [ -d $(WORSRCLINKUP)/$$l.lproj ]; then \
	    $(MKDIRS) $$l.lproj; \
	    cd $$l.lproj; \
	    for f in $(LOCALIZED_RESOURCE_FILES); do \
              if [ -f $(WORSRCLINKUP)/../$$l.lproj/$$f ]; then \
	        $(LN_S) -f $(WORSRCLINKUP)/../$$l.lproj/$$f .;\
	      fi;\
	    done;\
	    cd ..; \
	  else \
	   echo "Warning - $$l.lproj not found - ignoring";\
	  fi;\
	done
endif

PRINCIPAL_CLASS = $(strip $($(GNUSTEP_INSTANCE)_PRINCIPAL_CLASS))

ifeq ($(PRINCIPAL_CLASS),)
  PRINCIPAL_CLASS = $(GNUSTEP_INSTANCE)
endif

HAS_WOCOMPONENTS = $($(GNUSTEP_INSTANCE)_HAS_WOCOMPONENTS)
WOAPP_INFO_PLIST = $($(GNUSTEP_INSTANCE)_WOAPP_INFO_PLIST)
MAIN_MODEL_FILE = $(strip $(subst .gmodel,,$(subst .gorm,,$(subst .nib,,$($(GNUSTEP_INSTANCE)_MAIN_MODEL_FILE)))))

$(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX)/Info-gnustep.plist: $(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX)
	@(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)\";"; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  if [ "$(HAS_WOCOMPONENTS)" != "" ]; then \
	    echo "  HasWOComponents = \"$(HAS_WOCOMPONENTS)\";"; \
	  fi; \
	  echo "  NSMainNibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  if [ -r "$(GNUSTEP_INSTANCE)Info.plist" ]; then \
	    cat $(GNUSTEP_INSTANCE)Info.plist; \
	  fi; \
	  if [ "$(WOAPP_INFO_PLIST)" != "" ]; then \
	    cat $(WOAPP_INFO_PLIST); \
	  fi; \
	  echo "}") >$@

$(WOAPP_DIR_NAME)/$(WORSRCDIRINFIX):
	@$(MKDIRS) $@

$(WOAPP_DIR_NAME)/WebServerResources:
	@$(MKDIRS) $@

internal-woapp-install_::
	@($(MKINSTALLDIRS) $(GNUSTEP_WOAPPS); \
	if [ -e $(GNUSTEP_WOAPPS)/$(WOAPP_DIR_NAME) ]; then rm -rf $(GNUSTEP_WOAPPS)/$(WOAPP_DIR_NAME); fi; \
#	$(TAR) chf - --exclude=CVS --exclude=.svn --to-stdout $(WOAPP_DIR_NAME) | (cd $(GNUSTEP_WOAPPS); $(TAR) xf -))
	cp -LR $(WOAPP_DIR_NAME) $(GNUSTEP_WOAPPS)
ifneq ($(CHOWN_TO),)
	$(CHOWN) -R $(CHOWN_TO) $(GNUSTEP_WOAPPS)/$(WOAPP_DIR_NAME)
endif
ifeq ($(strip),yes)
	$(STRIP) $(GNUSTEP_WOAPPS)/$(WOAPP_FILE) 
endif

internal-woapp-uninstall_::
	(cd $(GNUSTEP_WOAPPS); rm -rf $(WOAPP_DIR_NAME))
endif

endif

## Local variables:
## mode: makefile
## End:
