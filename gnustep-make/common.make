#   -*-makefile-*-
#   common.make
#
#   Set all of the common environment variables.
#
#   Copyright (C) 1997, 2001 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
#   Author:  Nicola Pero <n.pero@mi.flashnet.it>
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

ifeq ($(COMMON_MAKE_LOADED),)
COMMON_MAKE_LOADED = yes

SHELL = /bin/sh

#
# Determine the compilation host and target
#
include $(GNUSTEP_MAKEFILES)/names.make

ifeq ($(GNUSTEP_FLATTENED),)
  GNUSTEP_HOST_DIR = $(GNUSTEP_HOST_CPU)/$(GNUSTEP_HOST_OS)
  GNUSTEP_TARGET_DIR = $(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)
  GNUSTEP_HOST_LDIR = $(GNUSTEP_HOST_DIR)/$(LIBRARY_COMBO)
  GNUSTEP_TARGET_LDIR = $(GNUSTEP_TARGET_DIR)/$(LIBRARY_COMBO)
else
  GNUSTEP_HOST_DIR = .
  GNUSTEP_TARGET_DIR = .
  GNUSTEP_HOST_LDIR = .
  GNUSTEP_TARGET_LDIR = .
endif

#
# Get the config information (host/target specific),
# this includes GNUSTEP_SYSTEM_ROOT etc.
#
include $(GNUSTEP_MAKEFILES)/$(GNUSTEP_TARGET_LDIR)/config.make

# GNUSTEP_BASE_INSTALL by default is `' - this is correct

# GNUSTEP_BUILD_DIR is the directory in which anything generated
# during the build will be placed.  '.' means it's the same as the
# source directory; this case is the default/common and we optimize
# for it whenever possible.
ifeq ($(GNUSTEP_BUILD_DIR),)
  GNUSTEP_BUILD_DIR = .
endif

#
# Scripts to run for parsing canonical names
#
CONFIG_GUESS_SCRIPT    = $(GNUSTEP_MAKEFILES)/config.guess
CONFIG_SUB_SCRIPT      = $(GNUSTEP_MAKEFILES)/config.sub
CONFIG_CPU_SCRIPT      = $(GNUSTEP_MAKEFILES)/cpu.sh
CONFIG_VENDOR_SCRIPT   = $(GNUSTEP_MAKEFILES)/vendor.sh
CONFIG_OS_SCRIPT       = $(GNUSTEP_MAKEFILES)/os.sh
CLEAN_CPU_SCRIPT       = $(GNUSTEP_MAKEFILES)/clean_cpu.sh
CLEAN_VENDOR_SCRIPT    = $(GNUSTEP_MAKEFILES)/clean_vendor.sh
CLEAN_OS_SCRIPT        = $(GNUSTEP_MAKEFILES)/clean_os.sh
ifeq ($(GNUSTEP_FLATTENED),)
  WHICH_LIB_SCRIPT \
	= $(GNUSTEP_MAKEFILES)/$(GNUSTEP_HOST_CPU)/$(GNUSTEP_HOST_OS)/which_lib
else
  WHICH_LIB_SCRIPT = $(GNUSTEP_MAKEFILES)/which_lib
endif
LD_LIB_PATH_SCRIPT     = $(GNUSTEP_MAKEFILES)/ld_lib_path.sh
TRANSFORM_PATHS_SCRIPT = $(GNUSTEP_MAKEFILES)/transform_paths.sh
REL_PATH_SCRIPT        = $(GNUSTEP_MAKEFILES)/relative_path.sh

# Take the makefiles from the system root
ifeq ($(GNUSTEP_MAKEFILES),)
  GNUSTEP_MAKEFILES = $(GNUSTEP_SYSTEM_ROOT)/Library/Makefiles
endif

#
# Sanity checks - only performed at the first make invocation
#
# FIXME - these checks should probably be removed and/or rewritten.
#

# Please note that _GNUSTEP_TOP_INVOCATION_DONE is set by the first
# time Master/rules.make is read, and propagated to sub-makes.  So
# this check will pass only the very first time we parse this file,
# and if Master/rules.make have not yet been parsed.
ifeq ($(_GNUSTEP_TOP_INVOCATION_DONE),)

# Sanity check on $PATH - NB: if PATH is wrong, we can't do certain things
# because we can't run the tools (not even using opentool as we can't even
# run opentool if PATH is wrong) - this is particularly bad for gui stuff

# Skip the check if we are on an Apple system.  I was told that you can't
# source GNUstep.sh before running Apple's PB and that the only
# friendly solution is to disable the check.
ifneq ($(FOUNDATION_LIB), apple)

# NB - we can't trust PATH here because it's what we are trying to
# check ... but hopefully if we (common.make) have been found, we
# can trust that at least $(GNUSTEP_MAKEFILES) is set up correctly :-)

# We want to check that this path is in the PATH
SYS_TOOLS_PATH = $(GNUSTEP_SYSTEM_ROOT)/Tools

# But on cygwin we might need to first fix it up ...
ifeq ($(findstring cygwin, $(GNUSTEP_HOST_OS)), cygwin)
  ifeq ($(shell echo "$(SYS_TOOLS_PATH)" | sed 's/^\([a-zA-Z]:.*\)//'),)
    SYS_TOOLS_PATH := $(shell $(GNUSTEP_MAKEFILES)/fixpath.sh -u $(SYS_TOOLS_PATH))
  endif
endif

# Under mingw paths are so confused this warning is not worthwhile
ifneq ($(findstring mingw, $(GNUSTEP_HOST_OS)), mingw)
  ifeq ($(findstring $(SYS_TOOLS_PATH),$(PATH)),)
    $(warning WARNING: Your PATH may not be set up correctly !)
    $(warning Please try again after running ". $(GNUSTEP_MAKEFILES)/GNUstep.sh")
  endif
endif

endif # code used when FOUNDATION_LIB != apple

endif # End of sanity checks run only at makelevel 0

#
# Get standard messages
#
include $(GNUSTEP_MAKEFILES)/messages.make

#
# Get flags/config options for core libraries
#

# First, work out precisely library combos etc
include $(GNUSTEP_MAKEFILES)/library-combo.make
# Then include custom makefiles with flags/config options
# This is meant to be used by the core libraries to override loading
# of the system makefiles from $(GNUSTEP_MAKEFILES)/Additional/*.make
# with their local copy (presumably more up-to-date)
ifneq ($(GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES),)
include $(GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES)
endif
# Then include makefiles with flags/config options installed by the 
# libraries themselves
-include $(GNUSTEP_MAKEFILES)/Additional/*.make

#
# Determine target specific settings
#
include $(GNUSTEP_MAKEFILES)/target.make

#
# GNUSTEP_INSTALLATION_DIR is the directory where all the things go. If you
# don't specify it defaults to GNUSTEP_LOCAL_ROOT.
#
ifeq ($(GNUSTEP_INSTALLATION_DIR),)
  GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)
endif

# Make it public and available to all submakes invocations
export GNUSTEP_INSTALLATION_DIR

#
# Variables specifying the installation directory paths
#
GNUSTEP_APPS                 = $(GNUSTEP_INSTALLATION_DIR)/Applications
GNUSTEP_TOOLS                = $(GNUSTEP_INSTALLATION_DIR)/Tools
GNUSTEP_LIBRARY              = $(GNUSTEP_INSTALLATION_DIR)/Library
GNUSTEP_SERVICES             = $(GNUSTEP_LIBRARY)/Services
ifeq ($(GNUSTEP_FLATTENED),yes)
  GNUSTEP_HEADERS              = $(GNUSTEP_INSTALLATION_DIR)/Library/Headers
else
  GNUSTEP_HEADERS              = $(GNUSTEP_INSTALLATION_DIR)/Library/Headers/$(LIBRARY_COMBO)
endif
GNUSTEP_APPLICATION_SUPPORT  = $(GNUSTEP_LIBRARY)/ApplicationSupport
GNUSTEP_BUNDLES 	     = $(GNUSTEP_LIBRARY)/Bundles
GNUSTEP_FRAMEWORKS	     = $(GNUSTEP_LIBRARY)/Frameworks
GNUSTEP_PALETTES 	     = $(GNUSTEP_LIBRARY)/ApplicationSupport/Palettes
GNUSTEP_LIBRARIES            = $(GNUSTEP_INSTALLATION_DIR)/Library/Libraries
GNUSTEP_RESOURCES            = $(GNUSTEP_LIBRARY)/Libraries/Resources
GNUSTEP_JAVA                 = $(GNUSTEP_LIBRARY)/Libraries/Java
GNUSTEP_DOCUMENTATION        = $(GNUSTEP_LIBRARY)/Documentation
GNUSTEP_DOCUMENTATION_MAN    = $(GNUSTEP_DOCUMENTATION)/man
GNUSTEP_DOCUMENTATION_INFO   = $(GNUSTEP_DOCUMENTATION)/info

# The default name of the makefile to be used in recursive invocations of make
ifeq ($(MAKEFILE_NAME),)
MAKEFILE_NAME = GNUmakefile
endif

# Now prepare the library and header flags - we first prepare the list
# of directories (trying to avoid duplicates in the list), then
# optionally remove the empty ones, then prepend -I / -L to them.
ifeq ($(GNUSTEP_FLATTENED),)

# The following variables have to be evaluated after setting dir to
# something, such as GNUSTEP_USER_ROOT.  When you evaluate them in
# that situation, they will generate paths according to the following
# definition.  Later, we'll systematically replace dir with
# GNUSTEP_USER_ROOT, the GNUSTEP_LOCAL_ROOT, then
# GNUSTEP_NETWORK_ROOT, then GNUSTEP_SYSTEM_ROOT.
GS_HEADER_PATH = \
 $(dir)/Library/Headers/$(LIBRARY_COMBO)/$(GNUSTEP_TARGET_DIR) \
 $(dir)/Library/Headers/$(LIBRARY_COMBO)

GS_LIBRARY_PATH = \
 $(dir)/Library/Libraries/$(GNUSTEP_TARGET_LDIR) \
 $(dir)/Library/Libraries/$(GNUSTEP_TARGET_DIR)

else

# In the flattened case, the paths to generate are considerably simpler.

GS_HEADER_PATH = $(dir)/Library/Headers
GS_LIBRARY_PATH = $(dir)/Library/Libraries

endif

ifeq ($(FOUNDATION_LIB), apple)
GS_FRAMEWORK_PATH = $(dir)/Library/Frameworks
else
GS_FRAMEWORK_PATH =
endif

# First, we add paths based on GNUSTEP_USER_ROOT.

# Please note that the following causes GS_HEADER_PATH to be evaluated
# with the variable dir equal $(GNUSTEP_USER_ROOT), which gives the
# effect we wanted.
GNUSTEP_HEADERS_DIRS = $(foreach dir,$(GNUSTEP_USER_ROOT),$(GS_HEADER_PATH))
GNUSTEP_LIBRARIES_DIRS = $(foreach dir,$(GNUSTEP_USER_ROOT),$(GS_LIBRARY_PATH))
GNUSTEP_FRAMEWORKS_DIRS = $(foreach dir,$(GNUSTEP_USER_ROOT),$(GS_FRAMEWORK_PATH))

# Second, if GNUSTEP_LOCAL_ROOT is different from GNUSTEP_USER_ROOT
# (which has already been added), we add the paths based on
# GNUSTEP_LOCAL_ROOT too.
ifneq ($(GNUSTEP_LOCAL_ROOT), $(GNUSTEP_USER_ROOT))
GNUSTEP_HEADERS_DIRS += $(foreach dir,$(GNUSTEP_LOCAL_ROOT),$(GS_HEADER_PATH))
GNUSTEP_LIBRARIES_DIRS += $(foreach dir,$(GNUSTEP_LOCAL_ROOT),$(GS_LIBRARY_PATH))
GNUSTEP_FRAMEWORKS_DIRS += $(foreach dir,$(GNUSTEP_LOCAL_ROOT),$(GS_FRAMEWORK_PATH))
endif

# Third, if GNUSTEP_NETWORK_ROOT is different from GNUSTEP_USER_ROOT and
# GNUSTEP_LOCAL_ROOT (which have already been added), we add the paths
# based on GNUSTEP_NETWORK_ROOT too.
ifneq ($(GNUSTEP_NETWORK_ROOT), $(GNUSTEP_USER_ROOT))
ifneq ($(GNUSTEP_NETWORK_ROOT), $(GNUSTEP_LOCAL_ROOT))
GNUSTEP_HEADERS_DIRS += $(foreach dir,$(GNUSTEP_NETWORK_ROOT),$(GS_HEADER_PATH))
GNUSTEP_LIBRARIES_DIRS += $(foreach dir,$(GNUSTEP_NETWORK_ROOT),$(GS_LIBRARY_PATH))
GNUSTEP_FRAMEWORKS_DIRS += $(foreach dir,$(GNUSTEP_NETWORK_ROOT),$(GS_FRAMEWORK_PATH))
endif
endif

# Last, if GNUSTEP_SYSTEM_ROOT is different from GNUSTEP_USER_ROOT,
# GNUSTEP_LOCAL_ROOT and GNUSTEP_NETWORK_ROOT (which have already been
# added), we add the pathe paths based on GNUSTEP_SYSTEM_ROOT too.
ifneq ($(GNUSTEP_SYSTEM_ROOT), $(GNUSTEP_USER_ROOT))
ifneq ($(GNUSTEP_SYSTEM_ROOT), $(GNUSTEP_LOCAL_ROOT))
ifneq ($(GNUSTEP_SYSTEM_ROOT), $(GNUSTEP_NETWORK_ROOT))
GNUSTEP_HEADERS_DIRS += $(foreach dir,$(GNUSTEP_SYSTEM_ROOT),$(GS_HEADER_PATH))
GNUSTEP_LIBRARIES_DIRS += $(foreach dir,$(GNUSTEP_SYSTEM_ROOT),$(GS_LIBRARY_PATH))
GNUSTEP_FRAMEWORKS_DIRS += $(foreach dir,$(GNUSTEP_SYSTEM_ROOT),$(GS_FRAMEWORK_PATH))
endif
endif
endif

ifeq ($(REMOVE_EMPTY_DIRS),yes)
 # This variable, when evaluated, gives $(dir) if dir is non-empty, and
 # nothing if dir is empty.
 remove_if_empty = $(dir $(word 1,$(wildcard $(dir)/*)))

 # Build the GNUSTEP_HEADER_FLAGS by removing the empty dirs from
 # GNUSTEP_HEADER_DIRS, then prepending -I to each of them
 #
 # Important - because this variable is defined with = and not :=, it
 # is only evaluated when it is used.  Which is good - it means we don't 
 # scan the directories and try to remove the empty one on each make 
 # invocation (eg, on 'make clean') - we only scan the dirs when we are using
 # GNUSTEP_HEADERS_FLAGS to compile.  Please make sure to keep this
 # behaviour otherwise scanning the directories each time a makefile is
 # read might slow down the package unnecessarily for operations like
 # make clean, make distclean etc.
 #
 # Doing this filtering still gives a 5% to 10% slowdown in compilation times
 # due to directory scanning, which is why is normally turned off by
 # default - by default we put all directories in compilation commands.
 GNUSTEP_HEADERS_FLAGS = \
   $(addprefix -I,$(foreach dir,$(GNUSTEP_HEADERS_DIRS),$(remove_if_empty)))
 GNUSTEP_LIBRARIES_FLAGS = \
   $(addprefix -L,$(foreach dir,$(GNUSTEP_LIBRARIES_DIRS),$(remove_if_empty)))
 GNUSTEP_FRAMEWORKS_FLAGS = \
   $(addprefix -F,$(foreach dir,$(GNUSTEP_FRAMEWORKS_DIRS),$(remove_if_empty)))
else
 # Default case, just add -I / -L
 GNUSTEP_HEADERS_FLAGS = $(addprefix -I,$(GNUSTEP_HEADERS_DIRS))
 GNUSTEP_LIBRARIES_FLAGS = $(addprefix -L,$(GNUSTEP_LIBRARIES_DIRS))
 GNUSTEP_FRAMEWORKS_FLAGS = $(addprefix -F,$(GNUSTEP_FRAMEWORKS_DIRS))
endif

ifeq ($(FOUNDATION_LIB), fd)

# Map OBJC_RUNTIME_LIB values to OBJC_RUNTIME values as used by
# libFoundation.  TODO/FIXME: Drop all this stuff and have
# libFoundation use OBJC_RUNTIME_LIB directly.

# TODO: Remove all this cruft.  Standardize.
ifeq ($(OBJC_RUNTIME_LIB), nx)
  OBJC_RUNTIME = NeXT
endif
ifeq ($(OBJC_RUNTIME_LIB), sun)
  OBJC_RUNTIME = Sun
endif
ifeq ($(OBJC_RUNTIME_LIB), apple)
  OBJC_RUNTIME = apple
endif
ifeq ($(OBJC_RUNTIME_LIB), gnu)
  OBJC_RUNTIME = GNU
endif
ifeq ($(OBJC_RUNTIME_LIB), gnugc)
  OBJC_RUNTIME = GNU
endif

# If all of the following really needed ?  If the system is not
# flattened, multiple Foundation libraries are not permitted anyway,
# so libFoundation could just put his headers in Foundation/.  If
# library combos are used, all headers are in a library-combo
# directory, so libFoundation could still put his headers in
# Foundation/ and no conflict should arise.  As for the
# GNUSTEP_TARGET_DIR, maybe we should key all of our headers in a
# GNUSTEP_TARGET_LDIR directory (rather than just a LIBRARY_COMBO
# directory).  But does it really matter in practice anyway ?
ifeq ($(GNUSTEP_FLATTENED),yes)
GNUSTEP_HEADERS_FND_DIRS = \
  $(GNUSTEP_USER_ROOT)/Library/Headers/libFoundation \
  $(GNUSTEP_LOCAL_ROOT)/Library/Headers/libFoundation \
  $(GNUSTEP_NETWORK_ROOT)/Library/Headers/libFoundation \
  $(GNUSTEP_SYSTEM_ROOT)/Library/Headers/libFoundation \
  $(GNUSTEP_USER_ROOT)/Library/Headers/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME) \
  $(GNUSTEP_LOCAL_ROOT)/Library/Headers/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME) \
  $(GNUSTEP_NETWORK_ROOT)/Library/Headers/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME) \
  $(GNUSTEP_SYSTEM_ROOT)/Library/Headers/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
else
GNUSTEP_HEADERS_FND_DIRS = \
  $(GNUSTEP_USER_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation \
  $(GNUSTEP_LOCAL_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation \
  $(GNUSTEP_NETWORK_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation \
  $(GNUSTEP_SYSTEM_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation \
  $(GNUSTEP_USER_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME) \
  $(GNUSTEP_LOCAL_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME) \
  $(GNUSTEP_NETWORK_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME) \
  $(GNUSTEP_SYSTEM_ROOT)/Library/Headers/$(LIBRARY_COMBO)/libFoundation/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
endif

ifeq ($(REMOVE_EMPTY_DIRS), yes)
 # Build the GNUSTEP_HEADERS_FND_FLAG by removing the empty dirs
 # from GNUSTEP_HEADERS_FND_DIRS, then prepending -I to each of them
 GNUSTEP_HEADERS_FND_FLAG = \
  $(addprefix -I,$(foreach dir,$(GNUSTEP_HEADERS_FND_DIRS),$(remove_if_empty)))
else
 # default case - simply prepend -I
 GNUSTEP_HEADERS_FND_FLAG = $(addprefix -I,$(GNUSTEP_HEADERS_FND_DIRS))
endif

# Just add the result of all this to the standard header flags.
GNUSTEP_HEADERS_FLAGS += $(GNUSTEP_HEADERS_FND_FLAG)

endif


#
# Overridable compilation flags
#
# FIXME: We use -fno-strict-aliasing to prevent annoying gcc3.3
# compiler warnings.  But we really need to investigate why the
# warning appear in the first place, if they are serious or not, and
# what can be done about it.
OBJCFLAGS = -fno-strict-aliasing
CFLAGS =
OBJ_DIR_PREFIX =

# If the compiler supports native ObjC exceptions and the user wants us to
# use them, turn them on!
ifeq ($(USE_OBJC_EXCEPTIONS), yes)
  OBJCFLAGS += -fobjc-exceptions -D_NATIVE_OBJC_EXCEPTIONS
endif

#
# Now decide whether to build shared objects or not.  Nothing depending
# on the value of the shared variable is allowed before this point!
#

#
# Fixup bundles to be always built as shared even when shared=no is given
#
ifeq ($(shared), no)
  ifeq ($(GNUSTEP_TYPE), bundle)
    $(warning "Static bundles are meaningless!  I am using shared=yes!")
    override shared = yes
    export shared
  endif
  ifeq ($(GNUSTEP_TYPE), framework)
    $(warning "Static frameworks are meaningless!  I am using shared=yes!")
    override shared = yes
    export shared
  endif
endif

# Enable building shared libraries by default. If the user wants to build a
# static library, he/she has to specify shared=no explicitly.
ifeq ($(HAVE_SHARED_LIBS), yes)
  # Unless shared=no has been purposedly set ...
  ifneq ($(shared), no)
    # ... set shared = yes
    shared = yes
  endif
endif

ifeq ($(shared), yes)
  LIB_LINK_CMD              =  $(SHARED_LIB_LINK_CMD)
  OBJ_DIR_PREFIX            += shared_
  INTERNAL_OBJCFLAGS        += $(SHARED_CFLAGS)
  INTERNAL_CFLAGS           += $(SHARED_CFLAGS)
  AFTER_INSTALL_LIBRARY_CMD =  $(AFTER_INSTALL_SHARED_LIB_CMD)
else
  LIB_LINK_CMD              =  $(STATIC_LIB_LINK_CMD)
  OBJ_DIR_PREFIX            += static_
  AFTER_INSTALL_LIBRARY_CMD =  $(AFTER_INSTALL_STATIC_LIB_CMD)
  LIBRARY_NAME_SUFFIX       := s$(LIBRARY_NAME_SUFFIX)
endif

ifeq ($(profile), yes)
  ADDITIONAL_FLAGS += -pg
  ifeq ($(LD), $(CC))
    INTERNAL_LDFLAGS += -pg
  endif
  OBJ_DIR_PREFIX += profile_
  LIBRARY_NAME_SUFFIX := p$(LIBRARY_NAME_SUFFIX)
endif

ifeq ($(debug), yes)
  OPTFLAG := $(filter-out -O%, $(OPTFLAG))
  ADDITIONAL_FLAGS += -g -Wall -DDEBUG -fno-omit-frame-pointer
  INTERNAL_JAVACFLAGS += -g -deprecation
  OBJ_DIR_PREFIX += debug_
else
  INTERNAL_JAVACFLAGS += -O
endif

OBJ_DIR_PREFIX += obj

ifeq ($(warn), no)
  ADDITIONAL_FLAGS += -UGSWARN
else
  ADDITIONAL_FLAGS += -DGSWARN
endif

ifeq ($(diagnose), no)
  ADDITIONAL_FLAGS += -UGSDIAGNOSE
else
  ADDITIONAL_FLAGS += -DGSDIAGNOSE
endif

ifneq ($(LIBRARY_NAME_SUFFIX),)
  LIBRARY_NAME_SUFFIX := _$(LIBRARY_NAME_SUFFIX)
endif

AUXILIARY_CPPFLAGS += $(GNUSTEP_DEFINE) \
		$(FND_DEFINE) $(GUI_DEFINE) $(BACKEND_DEFINE) \
		$(RUNTIME_DEFINE) $(FOUNDATION_LIBRARY_DEFINE)

INTERNAL_OBJCFLAGS += $(ADDITIONAL_FLAGS) $(OPTFLAG) $(OBJCFLAGS) \
			$(RUNTIME_FLAG)
INTERNAL_CFLAGS += $(ADDITIONAL_FLAGS) $(OPTFLAG)

# trick needed to replace a space with nothing
empty:=
space:= $(empty) $(empty)
GNUSTEP_OBJ_PREFIX = $(subst $(space),,$(OBJ_DIR_PREFIX))

#
# Support building of Multiple Architecture Binaries (MAB). The object files
# directory will be something like shared_obj/ix86_m68k_sun/
#
ifeq ($(arch),)
  ARCH_OBJ_DIR = $(GNUSTEP_TARGET_DIR)
else
  ARCH_OBJ_DIR = \
      $(shell echo $(CLEANED_ARCH) | sed -e 's/ /_/g')/$(GNUSTEP_TARGET_OS)
endif

ifeq ($(GNUSTEP_FLATTENED),)
  GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(ARCH_OBJ_DIR)/$(LIBRARY_COMBO)
else
  GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)
endif

GNUSTEP_OBJ_DIR = $(GNUSTEP_BUILD_DIR)/$(GNUSTEP_OBJ_DIR_NAME)

#
# Common variables for subprojects
#
SUBPROJECT_PRODUCT = subproject$(OEXT)

#
# Set JAVA_HOME if not set.
#
ifeq ($(JAVA_HOME),)
  # Else, try JDK_HOME
  ifeq ($(JDK_HOME),)
    # Else, try by finding the path of javac and removing 'bin/javac' from it
    ifeq ($(JAVAC),)
      JAVA_HOME = $(shell which javac | sed "s/bin\/javac//g")
    else # $(JAVAC) != "" 
      JAVA_HOME = $(shell which $(JAVAC) | sed "s/bin\/javac//g")
    endif  
  else # $(JDK_HOME) != ""
    JAVA_HOME = $(JDK_HOME) 
  endif
endif

#
# The java compiler.
#
ifeq ($(JAVAC),)
  JAVAC = $(JAVA_HOME)/bin/javac
endif

#
# The java header compiler.
#
ifeq ($(JAVAH),)
  JAVAH = $(JAVA_HOME)/bin/javah
endif

#
# Some GCJ Java Options
#

INTERNAL_AOT_JAVAFLAGS += -fjni -findirect-dispatch

ifeq ($(shared), yes)
  INTERNAL_AOT_JAVAFLAGS += $(SHARED_CFLAGS)
endif

INTERNAL_AOT_JAVAFLAGS += $(ADDITIONAL_FLAGS) $(OPTFLAG)

#
# Common variables - default values
#
# Because this file is included at the beginning of the user's
# GNUmakefile, the user can override these variables by setting them
# in the GNUmakefile.
BUNDLE_EXTENSION = .bundle
ifeq ($(profile), yes)
  APP_EXTENSION = profile
else
  ifeq ($(debug), yes)
    APP_EXTENSION = debug
  else
    APP_EXTENSION = app
  endif
endif



# We want total control over GNUSTEP_INSTANCE.
# GNUSTEP_INSTANCE determines wheter it's a Master or an Instance
# invocation.  Whenever we run a submake, we want it to be a Master
# invocation, unless we specifically set it to run as an Instance
# invocation by adding the GNUSTEP_INSTANCE=xxx flag.  Tell make not
# to mess with our games by passing this variable to submakes himself
unexport GNUSTEP_INSTANCE
unexport GNUSTEP_TYPE

endif # COMMON_MAKE_LOADED
