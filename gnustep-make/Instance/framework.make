#   -*-makefile-*-
#   Instance/framework.make
#
#   Instance Makefile rules to build GNUstep-based frameworks.
#
#   Copyright (C) 2000, 2001, 2002, 2003, 2004 Free Software Foundation, Inc.
#
#   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
#   Author: Nicola Pero <n.pero@mi.flashnet.it>
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

# FIXME - missing .PHONY declaration

# The name of the framework is in the FRAMEWORK_NAME variable.
# The list of framework resource files are in xxx_RESOURCE_FILES
# The list of framework web server resource files are in
#    xxx_WEBSERVER_RESOURCE_FILES
# The list of localized framework resource files is in
#    xxx_LOCALIZED_RESOURCE_FILES
# The list of localized framework web server resource files is in
#    xxx_WEBSERVER_LOCALIZED_RESOURCE_FILES
# The list of framework GSWeb components are in xxx_COMPONENTS
# The list of languages the framework supports is in xxx_LANGUAGES
# The list of framework resource directories are in xxx_RESOURCE_DIRS
# The list of framework subprojects directories are in xxx_SUBPROJECTS
# The name of the principal class is xxx_PRINCIPAL_CLASS
# The header files are in xxx_HEADER_FILES
# The directory where the header files are located is xxx_HEADER_FILES_DIR
#   (defaults to ./)
# The directory where to install the header files inside the library
#   installation directory is xxx_HEADER_FILES_INSTALL_DIR
#   (defaults to the framework name [without .framework]).  Can't be `.'
# The list of framework web server resource directories are in
#    xxx_WEBSERVER_RESOURCE_DIRS
# The list of localized framework web server GSWeb components are in
#    xxx_WEBSERVER_LOCALIZED_RESOURCE_DIRS
# xxx_CURRENT_VERSION_NAME is the compiled version name (default "A")
# xxx_MAKE_CURRENT_VERSION is used to decide if the framework version
#   we compiling should be made the current/default version or not
#   (default is "yes")
#
# where xxx is the framework name
#
#
# The HEADER_FILES_INSTALL_DIR might look somewhat weird - because in
# most if not all cases, you want it to be the framework name.  At the
# moment, it allows you to put headers for framework XXX in directory
# YYY, so that you can refer to them by using #include
# <YYY/MyHeader.h> rather than #include <XXX/MyHeader.h>.  It seems to
# be mostly used to have a framework with name XXX work as a drop-in
# replacement for another framework, which has name YYY -- and which
# might be installed at the same time :-).
#

# Warn about obsolete syntax
ifneq ($(CURRENT_VERSION_NAME),)
  $(warning CURRENT_VERSION_NAME is deprecated because it doesnt allow multiple frameworks with different versions to be built from warning the same GNUmakefile!  Please replace it with XXX_CURRENT_VERSION_NAME)
endif

# Warning - the following variable is also used in Master/rules.make
# to build the OWNING_PROJECT_HEADER_DIR for the framework's
# subprojects.  Make sure you keep them in sync if you change them.
CURRENT_VERSION_NAME = $($(GNUSTEP_INSTANCE)_CURRENT_VERSION_NAME)
ifeq ($(CURRENT_VERSION_NAME),)
  CURRENT_VERSION_NAME = A
endif

# xxx_MAKE_CURRENT_VERSION can be set to 'no' if you do not want the
# framework version that we are building from becoming the Current
# one.
ifneq ($($(GNUSTEP_INSTANCE)_MAKE_CURRENT_VERSION),)
  MAKE_CURRENT_VERSION = $($(GNUSTEP_INSTANCE)_MAKE_CURRENT_VERSION)
endif

ifeq ($(MAKE_CURRENT_VERSION),)
  MAKE_CURRENT_VERSION = yes
endif

# If there are no working symlinks, common.make sets
# FRAMEWORK_VERSION_SUPPORT to no, which unconditionally turn
# versioning off.  This means that we create no symlinks inside the
# xxx.framework directory for the various versions; that everything is
# put top-level as in the case of bundles.  So with
# FRAMEWORK_VERSION_SUPPORT = no, the Directory structure is:
#
# xxx.framework/libframework.dll.a
# xxx.framework/framework.dll
# xxx.framework/Resources
# xxx.framework/Headers
#
# The Headers, libframework.dll.a and framework.dll are then copied into
# the standard header/library locations so that they can be found by
# compiler/linker.  Given that there are no symlinks, there is no other
# way of doing this.
ifeq ($(FRAMEWORK_VERSION_SUPPORT),no)
  MAKE_CURRENT_VERSION = no
endif

# Set VERSION from xxx_VERSION
ifneq ($($(GNUSTEP_INSTANCE)_VERSION),)
  VERSION = $($(GNUSTEP_INSTANCE)_VERSION)
endif

ifeq ($(VERSION),)
  VERSION = 0.0.1
endif

# This is used on Apple to build frameworks which can be embedded into
# applications.  You usually set it to something like
# @executable_path/../Frameworks and then you can embed the framework
# in an application.
DYLIB_INSTALL_NAME_BASE = $($(GNUSTEP_INSTANCE)_DYLIB_INSTALL_NAME_BASE)

FRAMEWORK_DIR_NAME = $(GNUSTEP_INSTANCE).framework
FRAMEWORK_DIR = $(GNUSTEP_BUILD_DIR)/$(FRAMEWORK_DIR_NAME)

ifeq ($(FRAMEWORK_VERSION_SUPPORT), yes)
  FRAMEWORK_VERSION_DIR_NAME = $(FRAMEWORK_DIR_NAME)/Versions/$(CURRENT_VERSION_NAME)
else
  FRAMEWORK_VERSION_DIR_NAME = $(FRAMEWORK_DIR_NAME)
endif

FRAMEWORK_VERSION_DIR = $(GNUSTEP_BUILD_DIR)/$(FRAMEWORK_VERSION_DIR_NAME)

# This is not doing much at the moment, it is only defining
# HEADER_FILES, HEADER_FILES_DIR and HEADER_FILES_INSTALL_DIR in the
# standard way.  Please note that HEADER_FILES might be empty even if
# we have headers in subprojects that we need to manage and install.
# So we assume by default that we have some headers even if
# HEADER_FILES is empty.
include $(GNUSTEP_MAKEFILES)/Instance/Shared/headers.make
include $(GNUSTEP_MAKEFILES)/Instance/Shared/pch.make

# On windows, this is unfortunately required.
ifeq ($(BUILD_DLL), yes)
  LINK_AGAINST_ALL_LIBS = yes
endif

ifeq ($(LINK_AGAINST_ALL_LIBS), yes)
# Link against all libs ... but not the one we're compiling! (not sure
# when this could happen with frameworks, anyway it makes sense)
LIBRARIES_DEPEND_UPON += $(filter-out -l$(GNUSTEP_INSTANCE), \
   $(ADDITIONAL_GUI_LIBS) $(AUXILIARY_GUI_LIBS) \
   $(BACKEND_LIBS) \
   $(GUI_LIBS) $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS) \
   $(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) $(OBJC_LIBS) \
   $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS))
endif

INTERNAL_LIBRARIES_DEPEND_UPON =				\
  $(shell $(WHICH_LIB_SCRIPT)					\
   $(ALL_LIB_DIRS)						\
   $(LIBRARIES_DEPEND_UPON)					\
   debug=$(debug) profile=$(profile) shared=$(shared)		\
   libext=$(LIBEXT) shared_libext=$(SHARED_LIBEXT))

ifeq ($(FOUNDATION_LIB),gnu)

  # On GNUstep, build our dummy class to store information which
  # gnustep-base can find at run time.

  # An ObjC class name can not contain '-', but some people '-' this
  # in framework names.  So we need to encode the '-' in some way
  # into an ObjC class name. (since we're there, we also encode '+'
  # even if that's not really common).

  # What we do is, we use '_' as an escape character, and encode (in the 
  # order) as follows:
  #
  #  '_' is converted to '__'
  #  '-' is converted to '_0'
  #  '+' is converted to '_1'
  #

  # For example, 'Renaissance-Experimental' becomes 
  # 'Renaissance_0Experimental'.

  # GNUstep-base will convert the name back by applying the reverse rules 
  # in the reverse order.

  DUMMY_FRAMEWORK = NSFramework_$(subst +,_1,$(subst -,_0,$(subst _,__,$(GNUSTEP_INSTANCE))))
  DUMMY_FRAMEWORK_FILE = $(DERIVED_SOURCES_DIR)/$(DUMMY_FRAMEWORK).m
  DUMMY_FRAMEWORK_OBJ_FILE = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(DUMMY_FRAMEWORK).o)

  # The following file will hold the list of classes compiled into the
  # framework, ready to be included in the .plist file.  We include the
  # list of classes twice, in the object file itself (for when the
  # framework is loaded) and in the .plist (for tools which let you
  # browse in frameworks on disk and see lists of classes).  Please note
  # that reading the class list from the .plist requires gnustep-base to
  # have properly located the framework bundle on disk, while reading
  # the list from the object file itself does not (and so it's more
  # likely to work in a portable way), which is why we still save the
  # list in the object file rather than only putting it in the .plist.
  # Maybe this point should be discarded, and we should only store the class
  # list in the .plist file.
  DUMMY_FRAMEWORK_CLASS_LIST = $(DERIVED_SOURCES_DIR)/$(GNUSTEP_INSTANCE)-class-list
endif

FRAMEWORK_HEADER_FILES := $(addprefix $(FRAMEWORK_VERSION_DIR)/Headers/,$(HEADER_FILES))

ifeq ($(FRAMEWORK_VERSION_SUPPORT), yes)
  FRAMEWORK_CURRENT_DIR_NAME := $(FRAMEWORK_DIR_NAME)/Versions/Current
else
  FRAMEWORK_CURRENT_DIR_NAME := $(FRAMEWORK_DIR_NAME)
endif

FRAMEWORK_CURRENT_DIR := $(GNUSTEP_BUILD_DIR)/$(FRAMEWORK_CURRENT_DIR_NAME)
FRAMEWORK_LIBRARY_DIR_NAME := $(FRAMEWORK_VERSION_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)
FRAMEWORK_LIBRARY_DIR := $(GNUSTEP_BUILD_DIR)/$(FRAMEWORK_LIBRARY_DIR_NAME)
FRAMEWORK_CURRENT_LIBRARY_DIR_NAME := $(FRAMEWORK_CURRENT_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)
FRAMEWORK_CURRENT_LIBRARY_DIR := $(GNUSTEP_BUILD_DIR)/$(FRAMEWORK_CURRENT_LIBRARY_DIR_NAME)

ifneq ($(BUILD_DLL), yes)
FRAMEWORK_LIBRARY_FILE = lib$(GNUSTEP_INSTANCE)$(SHARED_LIBEXT)
VERSION_FRAMEWORK_LIBRARY_FILE = $(FRAMEWORK_LIBRARY_FILE).$(VERSION)

# By setting xxx_INTERFACE_VERSION you can change the soversion used
# when linking the library.  See comments in library.make for the
# variables with the same name for libraries.
ifeq ($($(GNUSTEP_INSTANCE)_INTERFACE_VERSION),)
  # By default, if VERSION is 1.0.0, INTERFACE_VERSION is 1
  INTERFACE_VERSION = $(word 1,$(subst ., ,$(VERSION)))
else
  INTERFACE_VERSION = $($(GNUSTEP_INSTANCE)_INTERFACE_VERSION)
endif
SONAME_FRAMEWORK_FILE = $(FRAMEWORK_LIBRARY_FILE).$(INTERFACE_VERSION)

else # BUILD_DLL

# When you build a DLL, you have to install it in a directory which is
# in your PATH.
ifeq ($(DLL_INSTALLATION_DIR),)
  DLL_INSTALLATION_DIR = $(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)
endif

# When we build a DLL, we also pass -DBUILD_lib{library_name}_DLL=1 to
# the preprocessor.  With the new DLL support, this is usually not
# needed; but in some cases some symbols are difficult and have to be
# exported/imported manually.  For these cases, the library header
# files can use this preprocessor define to know that they are
# included during compilation of the library itself, or are being
# imported by external code.  Typically with the new DLL support if a
# symbol can't be imported you have to mark it with
# __declspec(dllimport) when the library is not being compiled.
# __declspec(dllexport) is not particularly useful instead.

CLEAN_framework_NAME = $(subst -,_,$(GNUSTEP_INSTANCE))
SHARED_CFLAGS += -DBUILD_$(CLEAN_framework_NAME)_DLL=1

# FRAMEWORK_LIBRARY_FILE is the import library, libRenaissance.dll.a
FRAMEWORK_LIBRARY_FILE         = lib$(GNUSTEP_INSTANCE)$(DLL_LIBEXT)$(LIBEXT)
VERSION_FRAMEWORK_LIBRARY_FILE = $(FRAMEWORK_LIBRARY_FILE)
SONAME_FRAMEWORK_FILE  = $(FRAMEWORK_LIBRARY_FILE)

# LIB_LINK_DLL_FILE is the DLL library, Renaissance.dll
LIB_LINK_DLL_FILE    = $(GNUSTEP_INSTANCE)$(DLL_LIBEXT)

FRAMEWORK_OBJ_EXT = $(DLL_LIBEXT)
endif # BUILD_DLL

FRAMEWORK_FILE_NAME := $(FRAMEWORK_LIBRARY_DIR_NAME)/$(VERSION_FRAMEWORK_LIBRARY_FILE)
FRAMEWORK_FILE := $(GNUSTEP_BUILD_DIR)/$(FRAMEWORK_FILE_NAME)

ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_DIR),)
  FRAMEWORK_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_INSTALL_DIR)
endif

ifeq ($(FRAMEWORK_INSTALL_DIR),)
  FRAMEWORK_INSTALL_DIR = $(GNUSTEP_FRAMEWORKS)
endif

#
# Emit a warning for old deprecated functionality
#
ifneq ($($(GNUSTEP_INSTANCE)_TOOLS),)
  $(warning "Support for xxx_TOOLS has been removed from gnustep-make! Please rewrite your makefile code by compiling the tools separately, then add a xxx_COPY_INTO_DIR command for each of them to copy them into the framework.  Ask for help on gnustep mailing lists if you're confused.")
endif

#
# Now prepare the variables which are used by target-dependent commands
# defined in target.make
#
LIB_LINK_OBJ_DIR = $(FRAMEWORK_LIBRARY_DIR)
LIB_LINK_VERSION_FILE = $(VERSION_FRAMEWORK_LIBRARY_FILE)
LIB_LINK_SONAME_FILE = $(SONAME_FRAMEWORK_FILE)
LIB_LINK_FILE = $(FRAMEWORK_LIBRARY_FILE)
LIB_LINK_INSTALL_DIR = $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_LIBRARY_DIR_NAME)

ifneq ($(DYLIB_INSTALL_NAME_BASE),)
  LIB_LINK_INSTALL_NAME = $(DYLIB_INSTALL_NAME_BASE)/$(FRAMEWORK_FILE_NAME)
else
  # Use a relative path for easy relocation.
  LIB_LINK_INSTALL_NAME = $(GNUSTEP_INSTANCE).framework/$(GNUSTEP_INSTANCE)
endif


GNUSTEP_SHARED_BUNDLE_RESOURCE_PATH = $(FRAMEWORK_VERSION_DIR)/Resources
include $(GNUSTEP_MAKEFILES)/Instance/Shared/bundle.make

internal-framework-all_:: $(GNUSTEP_OBJ_DIR) \
			  shared-instance-pch-all \
                          build-framework

internal-framework-build-headers:: $(FRAMEWORK_HEADER_FILES) \
                                   build-framework-dirs

ifeq ($(MAKE_CURRENT_VERSION),yes)
# A target to build/reset the Current symlink to point to the newly
# compiled framework.  Only executed if MAKE_CURRENT_VERSION is yes.
UPDATE_CURRENT_SYMLINK_RULE = update-current-symlink
update-current-symlink: $(FRAMEWORK_VERSION_DIR)
	$(ECHO_NOTHING)cd $(FRAMEWORK_DIR)/Versions; \
	$(RM_LN_S) Current; \
	$(LN_S) $(CURRENT_VERSION_NAME) Current$(END_ECHO)

else
UPDATE_CURRENT_SYMLINK_RULE = 
endif

# Please note that test -h must be used instead of test -L because on old
# Sun Solaris, test -h works but test -L does not.
build-framework-dirs: $(DERIVED_SOURCES_DIR) \
                      $(FRAMEWORK_LIBRARY_DIR) \
                      $(FRAMEWORK_VERSION_DIR)/Headers \
                      $(FRAMEWORK_VERSION_DIR)/Resources \
                      $(FRAMEWORK_RESOURCE_DIRS) \
                      $(UPDATE_CURRENT_SYMLINK_RULE)
ifeq ($(FRAMEWORK_VERSION_SUPPORT), yes)
	$(ECHO_NOTHING)cd $(FRAMEWORK_DIR); \
	  if [ ! -h "Resources" ]; then \
	    $(RM_LN_S) Resources; \
	    $(LN_S) Versions/Current/Resources Resources; \
	  fi; \
	  if [ ! -h "Headers" ]; then \
	    $(RM_LN_S) Headers; \
	    $(LN_S) Versions/Current/Headers Headers; \
	  fi$(END_ECHO)
endif
	$(ECHO_NOTHING)cd $(DERIVED_SOURCES_DIR); \
	  if [ ! -h "$(HEADER_FILES_INSTALL_DIR)" ]; then \
	    $(RM_LN_S) ./$(HEADER_FILES_INSTALL_DIR); \
	    $(LN_S) ../$(FRAMEWORK_DIR_NAME)/Headers \
                    ./$(HEADER_FILES_INSTALL_DIR); \
	  fi$(END_ECHO)

$(FRAMEWORK_LIBRARY_DIR):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

$(FRAMEWORK_VERSION_DIR)/Headers:
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

$(DERIVED_SOURCES_DIR): $(DERIVED_SOURCES_DIR)/.stamp
$(DERIVED_SOURCES_DIR)/.stamp:
	$(ECHO_CREATING)$(MKDIRS) $(DERIVED_SOURCES_DIR); \
	touch $@$(END_ECHO)

# Need to share this code with the headers code ... but how.
$(FRAMEWORK_VERSION_DIR)/Headers/%.h: $(HEADER_FILES_DIR)/%.h $(FRAMEWORK_VERSION_DIR)/Headers
	$(ECHO_NOTHING)$(INSTALL_DATA) $< $@$(END_ECHO)


OBJC_OBJ_FILES_TO_INSPECT = $(OBJC_OBJ_FILES) $(SUBPROJECT_OBJ_FILES)

# FIXME - We should not depend on GNUmakefile - rather we should use
# Instance/Shared/stamp-string.make if we need to depend on the value
# of some make variables.  That would also detect a change in
# FRAMEWORK_INSTALL_DIR from the command line, not currently covered
# at the moment!
#
# To get the list of all classes, we use
# $(EXTRACT_CLASS_NAMES_COMMAND), which is defined in target.make
#
#
# The following rule will also build the DUMMY_FRAMEWORK_CLASS_LIST
# file.  This file is always created/deleted at the same time as the
# DUMMY_FRAMEWORK_FILE.
$(DUMMY_FRAMEWORK_FILE): $(DERIVED_SOURCES_DIR)/.stamp $(OBJ_FILES_TO_LINK) GNUmakefile
	$(ECHO_CREATING) classes=""; \
	for object_file in $(OBJC_OBJ_FILES_TO_INSPECT) __dummy__; do \
	  if [ "$$object_file" != "__dummy__" ]; then \
	    sym=`$(EXTRACT_CLASS_NAMES_COMMAND)`; \
	    classes="$$classes $$sym"; \
	  fi; \
	done; \
	classlist=""; \
	classarray=""; \
	for f in $$classes __dummy__ ; do \
	  if [ "$$f" != "__dummy__" ]; then \
	    if [ "$$classlist" = "" ]; then \
	      classlist="@\"$$f\""; \
	      classarray="(\"$$f\""; \
	    else \
	      classlist="$$classlist, @\"$$f\""; \
	      classarray="$$classarray, \"$$f\""; \
	    fi; \
	  fi; \
	done; \
	if [ "$$classlist" = "" ]; then \
	  classlist="NULL"; \
	  classarray="()"; \
	else \
	  classlist="$$classlist, NULL"; \
	  classarray="$$classarray)"; \
	fi; \
	echo "$$classarray" > $(DUMMY_FRAMEWORK_CLASS_LIST); \
	if [ "$(findstring $(GNUSTEP_SYSTEM_ROOT), $(FRAMEWORK_INSTALL_DIR))" = $(GNUSTEP_SYSTEM_ROOT) ]; then \
	  fw_env="@\"GNUSTEP_SYSTEM_ROOT\""; \
	elif [ "$(findstring $(GNUSTEP_LOCAL_ROOT), $(FRAMEWORK_INSTALL_DIR))" = $(GNUSTEP_LOCAL_ROOT) ]; then \
	  fw_env="@\"GNUSTEP_LOCAL_ROOT\""; \
	elif [ "$(findstring $(GNUSTEP_USER_ROOT), $(FRAMEWORK_INSTALL_DIR))" = $(GNUSTEP_USER_ROOT) ]; then \
	  fw_env="@\"GNUSTEP_USER_ROOT\""; \
	else \
	  fw_env="nil"; \
	fi; \
	fw_path=`echo $(FRAMEWORK_INSTALL_DIR) | sed 's/^$(subst /,\/,$(GNUSTEP_FRAMEWORKS))//'`; \
	if [ "$$fw_path" = "$(FRAMEWORK_INSTALL_DIR)" ]; then \
	  fw_path="nil"; \
	elif [ "$$fw_path" = "" ]; then \
	  fw_path="nil"; \
	else \
	  fw_path="@\"$$fw_path\""; \
	fi; \
	echo "#include <Foundation/NSString.h>" > $@; \
	echo "@interface $(DUMMY_FRAMEWORK)" >> $@; \
	echo "+ (NSString *)frameworkEnv;" >> $@; \
	echo "+ (NSString *)frameworkPath;" >> $@; \
	echo "+ (NSString *)frameworkVersion;" >> $@; \
	echo "+ (NSString **)frameworkClasses;" >> $@; \
	echo "@end" >> $@; \
	echo "@implementation $(DUMMY_FRAMEWORK)" >> $@; \
	echo "+ (NSString *)frameworkEnv { return $$fw_env; }" >> $@; \
	echo "+ (NSString *)frameworkPath { return $$fw_path; }" >> $@; \
	echo "+ (NSString *)frameworkVersion { return @\"$(CURRENT_VERSION_NAME)\"; }" >> $@; \
	echo "static NSString *allClasses[] = {$$classlist};" >> $@; \
	echo "+ (NSString **)frameworkClasses { return allClasses; }" >> $@;\
	echo "@end" >> $@$(END_ECHO)

ifeq ($(FOUNDATION_LIB),gnu)
$(DUMMY_FRAMEWORK_OBJ_FILE): $(DUMMY_FRAMEWORK_FILE)
	$(ECHO_COMPILING)$(CC) $< -c $(ALL_CPPFLAGS) $(ALL_OBJCFLAGS) -o $@$(END_ECHO)
endif

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
# When building native frameworks on Apple, we need to create a
# top-level symlink xxx.framework/xxx ---> the framework shared
# library. On Darwin (non-Apple) we do this as well since we can partially
# emulate frameworks (see the ld_lib_path.sh comments on this).

build-framework: $(FRAMEWORK_FILE) \
                 shared-instance-bundle-all \
                 $(FRAMEWORK_VERSION_DIR)/Resources/Info.plist \
                 $(GNUSTEP_BUILD_DIR)/$(GNUSTEP_INSTANCE).framework/$(GNUSTEP_INSTANCE)

# Please note that the following keeps the top-level symlink pointing
# to the framework in Current.  This is always correct, even if what
# we are compiling is not made the Current framework version, but if
# what we are compiling is not made the Current framework version, I
# think it's not our business to touch the Current stuff, so let's
# ignore it.  It's faster to ignore it anyway. ;-)
$(GNUSTEP_BUILD_DIR)/$(GNUSTEP_INSTANCE).framework/$(GNUSTEP_INSTANCE):
ifeq ($(MAKE_CURRENT_VERSION),yes)
	$(ECHO_NOTHING)cd $(GNUSTEP_BUILD_DIR)/$(GNUSTEP_INSTANCE).framework; \
	$(RM_LN_S) $(GNUSTEP_INSTANCE); \
	$(LN_S) Versions/Current/$(GNUSTEP_TARGET_LDIR)/$(GNUSTEP_INSTANCE) $(GNUSTEP_INSTANCE)$(END_ECHO)
endif

else

build-framework: $(FRAMEWORK_FILE) \
                 shared-instance-bundle-all \
                 $(FRAMEWORK_VERSION_DIR)/Resources/Info-gnustep.plist

endif

# We create a top-level symlink (/copy)
#
# xxx.framework/xxx --> <the framework object file>
#
# Normally, the framework object file that we link to is LIB_LINK_FILE
# (eg, libRenaissance.so); on Windows instead LIB_LINK_FILE is only
# the wrapper library (eg, libRenaissance.dll.a) and we want the
# top-level symlink to point to the real .dll: LIB_LINK_DLL_FILE
# (which is something like Renaissance.dll).  This is what is loaded
# at runtime if you load the framework as a bundle.
#
ifneq ($(BUILD_DLL), yes)
  LIB_LINK_FRAMEWORK_FILE = $(LIB_LINK_FILE)
else
  LIB_LINK_FRAMEWORK_FILE = $(LIB_LINK_DLL_FILE)
endif

$(FRAMEWORK_FILE): $(DUMMY_FRAMEWORK_OBJ_FILE) $(OBJ_FILES_TO_LINK)
	$(ECHO_LINKING) \
	$(LIB_LINK_CMD) || $(RM) $(FRAMEWORK_FILE) ; \
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(GNUSTEP_INSTANCE); \
	  $(LN_S) $(LIB_LINK_FRAMEWORK_FILE) $(GNUSTEP_INSTANCE)) \
	$(END_ECHO)

PRINCIPAL_CLASS = $(strip $($(GNUSTEP_INSTANCE)_PRINCIPAL_CLASS))

ifeq ($(PRINCIPAL_CLASS),)
  PRINCIPAL_CLASS = $(GNUSTEP_INSTANCE)
endif

MAIN_MODEL_FILE = $(strip $(subst .gmodel,,$(subst .gorm,,$(subst .nib,,$($(GNUSTEP_INSTANCE)_MAIN_MODEL_FILE)))))

# MacOSX-S frameworks
$(FRAMEWORK_VERSION_DIR)/Resources/Info.plist: $(FRAMEWORK_VERSION_DIR)/Resources
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)\";"; \
	  echo "  NSMainNibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  echo "}") >$@$(END_ECHO)

# GNUstep frameworks
$(FRAMEWORK_VERSION_DIR)/Resources/Info-gnustep.plist: $(FRAMEWORK_VERSION_DIR)/Resources $(DUMMY_FRAMEWORK_FILE)
	$(ECHO_CREATING)(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(GNUSTEP_INSTANCE)$(FRAMEWORK_OBJ_EXT)\";"; \
	  echo "  NSMainNibFile = \"$(MAIN_MODEL_FILE)\";"; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  echo "  Classes = "; \
	  cat $(DUMMY_FRAMEWORK_CLASS_LIST); \
	  echo "  ;"; \
	  echo "}") >$@$(END_ECHO)
	$(ECHO_NOTHING)if [ -r "$(GNUSTEP_INSTANCE)Info.plist" ]; then \
	   plmerge $@ $(GNUSTEP_INSTANCE)Info.plist; \
	 fi$(END_ECHO)

ifneq ($(BUILD_DLL),yes)

ifeq ($(FOUNDATION_LIB),gnu)

internal-framework-install_:: $(FRAMEWORK_INSTALL_DIR) \
                      $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR) \
                      $(GNUSTEP_HEADERS)
	$(ECHO_INSTALLING)rm -rf $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME); \
	(cd $(GNUSTEP_BUILD_DIR); $(TAR) cfX - $(GNUSTEP_MAKEFILES)/tar-exclude-list $(FRAMEWORK_DIR_NAME)) | (cd $(FRAMEWORK_INSTALL_DIR); $(TAR) xf -)$(END_ECHO)
ifneq ($(CHOWN_TO),)
	$(ECHO_CHOWNING)$(CHOWN) -R $(CHOWN_TO) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME)$(END_ECHO)
endif
ifeq ($(strip),yes)
	$(ECHO_STRIPPING)$(STRIP) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_FILE_NAME)$(END_ECHO)
endif
	$(ECHO_INSTALLING_HEADERS)cd $(GNUSTEP_HEADERS); \
	$(RM_LN_S) $(HEADER_FILES_INSTALL_DIR); \
	$(LN_S) `$(REL_PATH_SCRIPT) $(GNUSTEP_HEADERS) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME)/Headers` $(HEADER_FILES_INSTALL_DIR); \
	$(END_ECHO)
ifneq ($(CHOWN_TO),)
	$(ECHO_CHOWNING)cd $(GNUSTEP_HEADERS); \
	$(CHOWN) $(CHOWN_TO) $(HEADER_FILES_INSTALL_DIR); \
	$(END_ECHO)
endif
	$(ECHO_NOTHING)cd $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR); \
	$(RM_LN_S) $(FRAMEWORK_LIBRARY_FILE); \
	$(RM_LN_S) $(SONAME_FRAMEWORK_FILE); \
	$(RM_LN_S) $(VERSION_FRAMEWORK_LIBRARY_FILE); \
	$(LN_S) `$(REL_PATH_SCRIPT) $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_CURRENT_LIBRARY_DIR_NAME)/$(FRAMEWORK_LIBRARY_FILE)` $(FRAMEWORK_LIBRARY_FILE); \
	if test -r "$(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_CURRENT_LIBRARY_DIR_NAME)/$(SONAME_FRAMEWORK_FILE)"; then \
	  $(LN_S) `$(REL_PATH_SCRIPT) $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_CURRENT_LIBRARY_DIR_NAME)/$(SONAME_FRAMEWORK_FILE)` $(SONAME_FRAMEWORK_FILE); \
	fi; \
	$(LN_S) `$(REL_PATH_SCRIPT) $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_CURRENT_LIBRARY_DIR_NAME)/$(VERSION_FRAMEWORK_LIBRARY_FILE)` $(VERSION_FRAMEWORK_LIBRARY_FILE)$(END_ECHO)
ifneq ($(CHOWN_TO),)
	$(ECHO_CHOWNING)cd $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR); \
	$(CHOWN) $(CHOWN_TO) $(FRAMEWORK_LIBRARY_FILE); \
	if test -r "$(SONAME_FRAMEWORK_FILE)"; then \
	  $(CHOWN) $(CHOWN_TO) $(SONAME_FRAMEWORK_FILE); \
	fi; \
	$(CHOWN) $(CHOWN_TO) $(VERSION_FRAMEWORK_LIBRARY_FILE)$(END_ECHO)
endif

else

# This code for Apple OSX

internal-framework-install_:: $(FRAMEWORK_INSTALL_DIR)
	$(ECHO_INSTALLING)rm -rf $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME); \
	(cd $(GNUSTEP_BUILD_DIR); $(TAR) cfX - $(GNUSTEP_MAKEFILES)/tar-exclude-list $(FRAMEWORK_DIR_NAME)) | (cd $(FRAMEWORK_INSTALL_DIR); $(TAR) xf -)$(END_ECHO)
ifneq ($(CHOWN_TO),)
	$(ECHO_CHOWNING)$(CHOWN) -R $(CHOWN_TO) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME)$(END_ECHO)
endif
ifeq ($(strip),yes)
	$(ECHO_STRIPPING)$(STRIP) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_FILE_NAME)$(END_ECHO)
endif

endif

else # install DLL

internal-framework-install_:: $(FRAMEWORK_INSTALL_DIR) \
                      $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR) \
                      $(GNUSTEP_HEADERS) \
                      $(DLL_INSTALLATION_DIR)
	$(ECHO_INSTALLING)\
	rm -rf $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME); \
	(cd $(GNUSTEP_BUILD_DIR);\
	 $(TAR) cfX - $(GNUSTEP_MAKEFILES)/tar-exclude-list \
	        $(FRAMEWORK_DIR_NAME)) | (cd $(FRAMEWORK_INSTALL_DIR); \
	                                  $(TAR) xf -)$(END_ECHO)
ifneq ($(CHOWN_TO),)
	$(ECHO_CHOWNING)$(CHOWN) -R $(CHOWN_TO) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME)$(END_ECHO)
endif
ifeq ($(strip),yes)
	$(ECHO_STRIPPING)$(STRIP) $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_FILE_NAME)$(END_ECHO)
endif
	$(ECHO_INSTALLING_HEADERS)cd $(GNUSTEP_HEADERS); \
	if test -d "$(HEADER_FILES_INSTALL_DIR)"; then \
	  rm -Rf $(HEADER_FILES_INSTALL_DIR); \
	fi; \
        $(MKINSTALLDIRS) $(HEADER_FILES_INSTALL_DIR); \
	cd $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_VERSION_DIR_NAME)/Headers ; \
          $(TAR) cfX - $(GNUSTEP_MAKEFILES)/tar-exclude-list . | (cd  $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR); \
          $(TAR) xf - ); \
	$(END_ECHO)
ifneq ($(CHOWN_TO),)
	$(ECHO_CHOWNING)cd $(GNUSTEP_HEADERS); \
	$(CHOWN) -R $(CHOWN_TO) $(HEADER_FILES_INSTALL_DIR); \
	$(END_ECHO)
endif
	$(ECHO_NOTHING)$(INSTALL_PROGRAM) $(FRAMEWORK_LIBRARY_DIR)/$(LIB_LINK_DLL_FILE) \
          $(DLL_INSTALLATION_DIR)$(END_ECHO)
	$(ECHO_NOTHING)$(INSTALL_PROGRAM) $(FRAMEWORK_FILE_NAME) \
	  $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR)$(END_ECHO)

endif

$(DLL_INSTALLATION_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

# If Version support is disabled, then this directory is the same as
# the Resources directory in Shared/bundle.make for which we already
# have a rule.
ifeq ($(FRAMEWORK_VERSION_SUPPORT), yes)
$(FRAMEWORK_DIR)/Resources:
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)
endif

$(FRAMEWORK_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

$(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

$(GNUSTEP_HEADERS):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

ifneq ($(BUILD_DLL), yes)
# NB: We use '$(RM_LN_S)' to remove the symlinks to insure
#     that we do not remove customized real directories.  
internal-framework-uninstall_::
	$(ECHO_UNINSTALLING)if [ "$(HEADER_FILES)" != "" ]; then \
	  for file in $(HEADER_FILES) __done; do \
	    if [ $$file != __done ]; then \
	      rm -rf $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)/$$file ; \
	    fi; \
	  done; \
	fi; \
	$(RM_LN_S) $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR) ; \
	rm -rf $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME) ; \
	cd $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR); \
	$(RM_LN_S) $(FRAMEWORK_LIBRARY_FILE); \
	$(RM_LN_S) $(SONAME_FRAMEWORK_FILE); \
	$(RM_LN_S) $(VERSION_FRAMEWORK_LIBRARY_FILE); \
	$(END_ECHO)
else
internal-framework-uninstall_::
	$(ECHO_UNINSTALLING)if [ "$(HEADER_FILES)" != "" ]; then \
	  for file in $(HEADER_FILES) __done; do \
	    if [ $$file != __done ]; then \
	      rm -rf $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR)/$$file ; \
	    fi; \
	  done; \
	fi; \
	$(RM_LN_S) $(GNUSTEP_HEADERS)/$(HEADER_FILES_INSTALL_DIR) ; \
	rm -rf $(FRAMEWORK_INSTALL_DIR)/$(FRAMEWORK_DIR_NAME) ; \
	cd $(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR); \
	$(RM_LN_S) $(FRAMEWORK_LIBRARY_FILE); \
	cd $(DLL_INSTALLATION_DIR); \
	$(RM_LN_S) $(LIB_LINK_DLL_FILE); \
	$(END_ECHO)
endif
#
# Cleaning targets
#
internal-framework-clean::
	$(ECHO_NOTHING)rm -rf $(GNUSTEP_OBJ_DIR) \
	       $(PSWRAP_C_FILES) $(PSWRAP_H_FILES) \
	       $(FRAMEWORK_DIR) $(DERIVED_SOURCES_DIR)$(END_ECHO)

internal-framework-distclean::
	$(ECHO_NOTHING)cd $(GNUSTEP_BUILD_DIR); \
	  rm -rf shared_obj static_obj shared_debug_obj \
	  shared_profile_obj static_debug_obj static_profile_obj \
	  shared_profile_debug_obj static_profile_debug_obj$(END_ECHO)

include $(GNUSTEP_MAKEFILES)/Instance/Shared/strings.make
