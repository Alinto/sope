#   -*-makefile-*-
#   rules.make
#
#   All of the common makefile rules.
#
#   Copyright (C) 1997, 2001 Free Software Foundation, Inc.
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

# prevent multiple inclusions

# NB: This file is internally protected against multiple inclusions.
# But for perfomance reasons, you might want to check the
# RULES_MAKE_LOADED variable yourself and include this file only if it
# is empty.  That allows make to skip reading the file entirely when it 
# has already been read.  We use this trick for all system makefiles.
ifeq ($(RULES_MAKE_LOADED),)
RULES_MAKE_LOADED=yes

# Include the Master rules at the beginning because the 'all' rule must be
# first on the first invocation without a specified target.
ifeq ($(GNUSTEP_INSTANCE),)
include $(GNUSTEP_MAKEFILES)/Master/rules.make
endif

#
# If INSTALL_AS_USER and/or INSTALL_AS_GROUP are defined, pass them down
# to submakes.  There are two reasons - 
#
# 1. so that if you set them in a GNUmakefile, they get passed down
#    to automatically generated sources/GNUmakefiles (such as Java wrappers)
# 2. so that if you type `make install INSTALL_AS_USER=nicola' in a directory,
#    the INSTALL_AS_USER=nicola gets automatically used in all subdirectories.
#
# Warning - if you want to hardcode a INSTALL_AS_USER in a GNUmakefile, then
# you shouldn't rely on us to pass it down to subGNUmakefiles - you should
# rather hardcode INSTALL_AS_USER in all your GNUmakefiles (or better have
# a makefile fragment defining INSTALL_AS_USER in the top-level and include
# it in all GNUmakefiles) - otherwise what happens is that if you go in a
# subdirectory and type 'make install' there, it will not get the 
# INSTALL_AS_USER from the higher level GNUmakefile, so it will install with
# the wrong user!  For this reason, if you need to hardcode INSTALL_AS_USER
# in GNUmakefiles, make sure it's hardcoded *everywhere*.
#
ifneq ($(INSTALL_AS_USER),)
  export INSTALL_AS_USER
endif

ifneq ($(INSTALL_AS_GROUP),)
  export INSTALL_AS_GROUP
endif


# In subprojects, will be set by the recursive make invocation on the
# make command line to be [../../]../derived_src
DERIVED_SOURCES = derived_src
DERIVED_SOURCES_DIR = $(GNUSTEP_BUILD_DIR)/$(DERIVED_SOURCES)

# Always include all the compilation flags and generic compilation
# rules, because the user, in his GNUmakefile.postamble, might want to
# add manual commands for example to after-all, which are processed
# during the Master invocation, but yet can compile or install stuff
# and need access to all compilation/installation flags and locations
# and basic rules.

#
# Manage stripping
#
ifeq ($(strip),yes)
INSTALL_PROGRAM += -s
export strip
endif

#
# Prepare the arguments to install to set user/group of installed files
#
INSTALL_AS = 

ifneq ($(INSTALL_AS_USER),)
INSTALL_AS += -o $(INSTALL_AS_USER)
endif

ifneq ($(INSTALL_AS_GROUP),)
INSTALL_AS += -g $(INSTALL_AS_GROUP)
endif

# Redefine INSTALL to include these flags.  This automatically
# redefines INSTALL_DATA and INSTALL_PROGRAM as well, because they are
# define in terms of INSTALL.
INSTALL += $(INSTALL_AS)

# Sometimes, we install without using INSTALL - typically using tar.
# In those cases, we run chown after having installed, in order to
# fixup the user/group.

#
# Prepare the arguments to chown to set user/group of installed files.
#
ifneq ($(INSTALL_AS_GROUP),)
CHOWN_TO = $(strip $(INSTALL_AS_USER)).$(strip $(INSTALL_AS_GROUP))
else 
CHOWN_TO = $(strip $(INSTALL_AS_USER))
endif

# You need to run CHOWN manually, but only if CHOWN_TO is non-empty.

#
# Pass the CHOWN_TO argument to MKINSTALLDIRS
# All installation directories should be created using MKINSTALLDIRS
# to make sure we set the correct user/group.  Local directories should
# be created using MKDIRS instead because we don't want to set user/group.
#
ifneq ($(CHOWN_TO),)
 MKINSTALLDIRS = $(MKDIRS) -c $(CHOWN_TO)
 # Fixup the library installation commands if needed so that we change
 # ownership of the links as well
 ifeq ($(shared),yes)
  AFTER_INSTALL_LIBRARY_CMD += ; $(AFTER_INSTALL_SHARED_LIB_CHOWN)
 endif
else
 MKINSTALLDIRS = $(MKDIRS)
endif

#
# If this is part of the compilation of a framework,
# add -I[$GNUSTEP_BUILD_DIR][../../../etc]derived_src so that the code
# can include framework headers simply using `#include
# <MyFramework/MyHeader.h>'
#
# If it's a framework makefile, FRAMEWORK_NAME will be non-empty.  If
# it's a framework subproject, OWNING_PROJECT_HEADER_DIR_NAME will be
# non-empty.
#
ifneq ($(FRAMEWORK_NAME)$(OWNING_PROJECT_HEADER_DIR_NAME),)
  DERIVED_SOURCES_HEADERS_FLAG = -I$(DERIVED_SOURCES_DIR)
endif

#
# Include rules to built the instance
#
# this fixes up ADDITIONAL_XXXFLAGS as well, which is why we include it
# before using ADDITIONAL_XXXFLAGS
#
ifneq ($(GNUSTEP_INSTANCE),)
include $(GNUSTEP_MAKEFILES)/Instance/rules.make
endif

#
# Implement ADDITIONAL_NATIVE_LIBS
#
# A native lib is a framework on apple, and a shared library
# everywhere else.  Here we provide the appropriate link flags
# to support it transparently on the two platforms.
#
ifeq ($(FOUNDATION_LIB),apple)
  ADDITIONAL_OBJC_LIBS += $(foreach lib,$(ADDITIONAL_NATIVE_LIBS),-framework $(lib))
else
  ADDITIONAL_OBJC_LIBS += $(foreach lib,$(ADDITIONAL_NATIVE_LIBS),-l$(lib))
endif

#
# Auto dependencies
#
# -MMD -MP tells gcc to generate a .d file for each compiled file, 
# which includes makefile rules adding dependencies of the compiled
# file on all the header files the source file includes ...
#
# next time `make' is run, we include the .d files for the previous
# run (if we find them) ... this automatically adds dependencies on
# the appropriate header files 
#

# Warning - the following variable name might change
ifeq ($(AUTO_DEPENDENCIES),yes)
ifeq ($(AUTO_DEPENDENCIES_FLAGS),)
  AUTO_DEPENDENCIES_FLAGS = -MMD -MP
endif
endif

# The difference between ADDITIONAL_XXXFLAGS and AUXILIARY_XXXFLAGS is the
# following:
#
#  ADDITIONAL_XXXFLAGS are set freely by the user GNUmakefile
#
#  AUXILIARY_XXXFLAGS are set freely by makefile fragments installed by
#                     auxiliary packages.  For example, gnustep-db installs
#                     a gdl.make file.  If you want to use gnustep-db in
#                     your tool, you `include $(GNUSTEP_MAKEFILES)/gdl.make'
#                     and that will add the appropriate flags to link against
#                     gnustep-db.  Those flags are added to AUXILIARY_XXXFLAGS.
#
# Why can't ADDITIONAL_XXXFLAGS and AUXILIARY_XXXFLAGS be the same variable ?
# Good question :-) I'm not sure but I think the original reason is that 
# users tend to think they can do whatever they want with ADDITIONAL_XXXFLAGS,
# like writing 
# ADDITIONAL_XXXFLAGS = -Verbose
# (with a '=' instead of a '+=', thus discarding the previous value of
# ADDITIONAL_XXXFLAGS) without caring for the fact that other makefiles 
# might need to add something to ADDITIONAL_XXXFLAGS.
#
# So the idea is that ADDITIONAL_XXXFLAGS is reserved for the users to
# do whatever mess they like with them, while in makefile fragments
# from packages we use a different variable, which is subject to a stricter 
# control, requiring package authors to always write
#
#  AUXILIARY_XXXFLAGS += -Verbose
#
# in their auxiliary makefile fragments, to make sure they don't
# override flags from different packages, just add to them.
#
# When building up command lines inside gnustep-make, we always need
# to add both AUXILIARY_XXXFLAGS and ADDITIONAL_XXXFLAGS to all
# compilation/linking/etc command.
#

ALL_CPPFLAGS = $(AUTO_DEPENDENCIES_FLAGS) $(CPPFLAGS) $(ADDITIONAL_CPPFLAGS) \
               $(AUXILIARY_CPPFLAGS)

ALL_OBJCFLAGS = $(INTERNAL_OBJCFLAGS) $(ADDITIONAL_OBJCFLAGS) \
   $(AUXILIARY_OBJCFLAGS) $(ADDITIONAL_INCLUDE_DIRS) \
   $(AUXILIARY_INCLUDE_DIRS) \
   $(DERIVED_SOURCES_HEADERS_FLAG) \
   -I. $(SYSTEM_INCLUDES) \
   $(GNUSTEP_HEADERS_FLAGS) \
   $(GNUSTEP_FRAMEWORKS_FLAGS)

ALL_CFLAGS = $(INTERNAL_CFLAGS) $(ADDITIONAL_CFLAGS) \
   $(AUXILIARY_CFLAGS) $(ADDITIONAL_INCLUDE_DIRS) \
   $(AUXILIARY_INCLUDE_DIRS) \
   $(DERIVED_SOURCES_HEADERS_FLAG) \
   -I. $(SYSTEM_INCLUDES) \
   $(GNUSTEP_HEADERS_FLAGS) \
   $(GNUSTEP_FRAMEWORKS_FLAGS)

# if you need, you can define ADDITIONAL_CCFLAGS to add C++ specific flags
ALL_CCFLAGS = $(ADDITIONAL_CCFLAGS) $(AUXILIARY_CCFLAGS)

# If you need, you can define ADDITIONAL_OBJCCFLAGS to add ObjC++
# specific flags.  Please note that for maximum flexibility,
# ADDITIONAL_OBJCFLAGS are *not* used to compile ObjC++.  You can add
# different additional flags to ObjC and to ObjC++ by specifying
# different ADDITIONAL_OBJCFLAGS and ADDITIONAL_OBJCCFLAGS.  The
# internal ObjC flags instead are used in the same way for ObjC and
# ObjC++.  We have to use AUXILIARY_OBJCFLAGS though as gnustep-base
# puts its NXConstantString flags in there.  Presumably gnustep-base
# could be changed to put them in AUXILIARY_OBJCCFLAGS too and then we
# can remove AUXILIARY_OBJCCFLAGS from the following line, which would
# be cleaner. :-)
ALL_OBJCCFLAGS = $(INTERNAL_OBJCFLAGS) $(ADDITIONAL_OBJCCFLAGS) \
   $(AUXILIARY_OBJCFLAGS) \
   $(AUXILIARY_OBJCCFLAGS) $(ADDITIONAL_INCLUDE_DIRS) \
   $(AUXILIARY_INCLUDE_DIRS) \
   $(DERIVED_SOURCES_HEADERS_FLAG) \
   -I. $(SYSTEM_INCLUDES) \
   $(GNUSTEP_HEADERS_FLAGS) \
   $(GNUSTEP_FRAMEWORKS_FLAGS)

INTERNAL_CLASSPATHFLAGS = -classpath ./$(subst ::,:,:$(strip $(ADDITIONAL_CLASSPATH)):)$(CLASSPATH)

ALL_JAVACFLAGS = $(INTERNAL_CLASSPATHFLAGS) $(INTERNAL_JAVACFLAGS) \
$(ADDITIONAL_JAVACFLAGS) $(AUXILIARY_JAVACFLAGS)

ALL_JAVAHFLAGS = $(INTERNAL_CLASSPATHFLAGS) $(ADDITIONAL_JAVAHFLAGS) \
$(AUXILIARY_JAVAHFLAGS)

ifeq ($(shared),no)
  ALL_LDFLAGS = $(STATIC_LDFLAGS)
else
  ALL_LDFLAGS =
endif
ALL_LDFLAGS += $(ADDITIONAL_LDFLAGS) $(AUXILIARY_LDFLAGS) $(GUI_LDFLAGS) \
               $(BACKEND_LDFLAGS) $(SYSTEM_LDFLAGS) $(INTERNAL_LDFLAGS)
# In some cases, ld is used for linking instead of $(CC), so we can't use
# this in ALL_LDFLAGS
CC_LDFLAGS = $(RUNTIME_FLAG)

ALL_LIB_DIRS = $(ADDITIONAL_FRAMEWORK_DIRS) $(AUXILIARY_FRAMEWORK_DIRS) \
   $(ADDITIONAL_LIB_DIRS) $(AUXILIARY_LIB_DIRS) \
   $(GNUSTEP_LIBRARIES_FLAGS) \
   $(GNUSTEP_FRAMEWORKS_FLAGS) \
   $(SYSTEM_LIB_DIR)

# We use .plist (property-list files, see gnustep-base) in quite a few
# cases.  Whenever a .plist file is required, you can/will be allowed
# to provide a .cplist file instead (at the moment, it is only
# implemented for applications' xxxInfo.plist).  A .cplist file is a
# property-list file with C preprocessor conditionals.  gnustep-make
# will automatically generate the .plist file from the .cplist file by
# running the C preprocessor.

# The CPLISTFLAGS are the flags used when running the C preprocessor
# to generate a .plist file from a .cplist file.
ALL_CPLISTFLAGS = -P -x c -traditional

ifeq ($(FOUNDATION_LIB), gnu)
  ALL_CPLISTFLAGS += -DGNUSTEP
else
  ifeq ($(FOUNDATION_LIB), apple)
    ALL_CPLISTFLAGS += -DAPPLE
  else
      ifeq ($(FOUNDATION_LIB), nx)
        ALL_CPLISTFLAGS += -DNEXT
      else
        ALL_CPLISTFLAGS += -DUNKNOWN
      endif
  endif
endif

ALL_CPLISTFLAGS += $(ADDITIONAL_CPLISTFLAGS) $(AUXILIARY_CPLISTFLAGS)


# If we are using Windows32 DLLs, we pass -DGNUSTEP_WITH_DLL to the
# compiler.  This preprocessor define might be used by library header
# files to know they are included from external code needing to use
# the library symbols, so that the library header files can in this
# case use __declspec(dllimport) to mark symbols as needing to be put
# into the import table for the executable/library/whatever that is
# being compiled.
#
# In the new DLL support, this is usually no longer needed.  The
# compiler does it all automatically.  But in some cases, some symbols
# can not be automatically imported and you might want to declare them
# specially.  For those symbols, this define is handy.
#
ifeq ($(BUILD_DLL),yes)
ALL_CPPFLAGS += -DGNUSTEP_WITH_DLL
endif

# General rules
VPATH = .

# Disable all built-in suffixes for performance.
.SUFFIXES:

# Then define our own.
.SUFFIXES: .m .c .psw .java .h .cpp .cxx .C .cc .cp .mm

.PRECIOUS: %.c %.h $(GNUSTEP_OBJ_DIR)/%${OEXT}

# Disable all built-in rules with a vague % as target, for performance.
%: %.c

%: %.cpp

%: %.cc

%: %.C

(%): %

%:: %,v

%:: RCS/%,v

%:: RCS/%

%:: s.%

%:: SCCS/s.%

#
# In exceptional conditions, you might need to want to use different compiler
# flags for a file (for example, if a file doesn't compile with optimization
# turned on, you might want to compile that single file with optimizations
# turned off).  gnustep-make allows you to do this - you can specify special 
# flags to be used when compiling a *specific* file in two ways - 
#
# xxx_FILE_FLAGS (where xxx is the file name, such as main.m) 
#                are special compilation flags to be used when compiling xxx
#
# xxx_FILE_FILTER_OUT_FLAGS (where xxx is the file name, such as mframe.m)
#                is a filter-out make pattern of flags to be filtered out 
#                from the compilation flags when compiling xxx.
#
# Typical examples:
#
# Disable optimization flags for the file NSInvocation.m:
# NSInvocation.m_FILE_FILTER_OUT_FLAGS = -O%
#
# Disable optimization flags for the same file, and also remove 
# -fomit-frame-pointer:
# NSInvocation.m_FILE_FILTER_OUT_FLAGS = -O% -fomit-frame-pointer
#
# Force the compiler to warn for #import if used in file file.m:
# file.m_FILE_FLAGS = -Wimport
# file.m_FILE_FILTER_OUT_FLAGS = -Wno-import
#

# Please don't be scared by the following rules ... In normal
# situations, $<_FILTER_OUT_FLAGS is empty, and $<_FILE_FLAGS is empty
# as well, so the following rule is simply equivalent to
# $(CC) $< -c $(ALL_CPPFLAGS) $(ALL_CFLAGS) -o $@
# and similarly all the rules below
$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.c
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_CFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.m
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_OBJCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.C
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_CFLAGS)   \
	                                                $(ALL_CCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.cc
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_CFLAGS)   \
	                                                $(ALL_CCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.cpp
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_CFLAGS)   \
	                                                $(ALL_CCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.cxx
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_CFLAGS)   \
	                                                $(ALL_CCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.cp
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_CFLAGS)   \
	                                                $(ALL_CCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

$(GNUSTEP_OBJ_DIR)/%${OEXT} : %.mm
	$(ECHO_COMPILING)$(CC) $< -c \
	      $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPPFLAGS) \
	                                                $(ALL_OBJCCFLAGS)) \
	      $($<_FILE_FLAGS) -o $@$(END_ECHO)

%.class : %.java
	$(ECHO_COMPILING)$(JAVAC) \
	         $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_JAVACFLAGS)) \
	         $($<_FILE_FLAGS) $<$(END_ECHO)

# A jni header file which is created using JAVAH
# Example of how this rule will be applied: 
# gnu/gnustep/base/NSObject.h : gnu/gnustep/base/NSObject.java
#	javah -o gnu/gnustep/base/NSObject.h gnu.gnustep.base.NSObject
%.h : %.java
	$(ECHO_JAVAHING)$(JAVAH) \
	         $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_JAVAHFLAGS)) \
	         $($<_FILE_FLAGS) -o $@ $(subst /,.,$*)$(END_ECHO)

%.c : %.psw
	pswrap -h $*.h -o $@ $<

# The following rule is needed because in frameworks you might need
# the .h files before the .c files are compiled.
%.h : %.psw
	pswrap -h $@ -o $*.c $<

# Rule to generate a .plist file (a property list file) by running the
# preprocessor on a .cplist file (a property list file with embedded C
# preprocessor conditionals).  Useful in order to have a single
# xxxInfo.plist file for multiple platforms (read GNUstep and Apple)
# for the same application (to make portability easier).  You can have
# a single xxxInfo.cplist file, and xxxInfo.plist will automatically
# be generated by gnustep-make from xxxInfo.cplist by running the
# preprocessor.
#
# Unfortunately, on some platforms (Apple) the preprocessor emits
# unwanted and unrequested #pragma statements.  We use sed to filter
# them out.
#
%.plist : %.cplist
	$(ECHO_PREPROCESSING)$(CPP) \
	          $(filter-out $($<_FILE_FILTER_OUT_FLAGS),$(ALL_CPLISTFLAGS))\
	          $($<_FILE_FLAGS) $< | sed '/^#pragma/d' > $@$(END_ECHO)

# The following rule builds a .c file from a lex .l file.
# You can define LEX_FLAGS if you need them.
%.c: %.l
	$(LEX) $(LEX_FLAGS) -t $< > $@

# The following rule builds a .c file from a yacc/bison .y file.
# You can define YACC_FLAGS if you need them.
%.c: %.y
	$(YACC) $(YACC_FLAGS) $<
	mv -f y.tab.c $@

#
# Special mingw32 specific rules to compile Windows resource files (.rc files)
# into object files.
#
ifeq ($(findstring mingw32, $(GNUSTEP_TARGET_OS)), mingw32)
# Add the .rc suffix on Windows.
.SUFFIXES: .rc

# A rule to generate a .o file from the .rc file.
$(GNUSTEP_OBJ_DIR)/%${OEXT}: %.rc
	$(ECHO_COMPILING)windres $< $@$(END_ECHO)
endif

#
# Special cygwin specific rules to compile Windows resource files (.rc files)
# into object files. (this is the same rule as mingw32)
#
ifeq ($(findstring cygwin, $(GNUSTEP_TARGET_OS)), cygwin)
# Add the .rc suffix on Windows.
.SUFFIXES: .rc

# A rule to generate a .o file from the .rc file.
$(GNUSTEP_OBJ_DIR)/%${OEXT}: %.rc
	$(ECHO_COMPILING)windres $< $@$(END_ECHO)
endif

# The following dummy rules are needed for performance - we need to
# prevent make from spending time trying to compute how/if to rebuild
# the system makefiles!  the following rules tell him that these files
# are always up-to-date

$(GNUSTEP_MAKEFILES)/*.make: ;

ifeq ($(GNUSTEP_FLATTENED)), )
$(GNUSTEP_MAKEFILES)/$(GNUSTEP_TARGET_DIR)/$(LIBRARY_COMBO)/config.make: ;
endif

$(GNUSTEP_MAKEFILES)/Additional/*.make: ;

$(GNUSTEP_MAKEFILES)/Master/*.make: ;

$(GNUSTEP_MAKEFILES)/Instance/*.make: ;

$(GNUSTEP_MAKEFILES)/Instance/Shared/*.make: ;

$(GNUSTEP_MAKEFILES)/Instance/Documentation/*.make: ;

# The rule to create the GNUSTEP_BUILD_DIR if any.
ifneq ($(GNUSTEP_BUILD_DIR),.)
$(GNUSTEP_BUILD_DIR):
	$(ECHO_CREATING)$(MKDIRS) $(GNUSTEP_BUILD_DIR)$(END_ECHO)
endif

# The rule to create the objects file directory.
$(GNUSTEP_OBJ_DIR):
ifeq ($(HAS_LN_S),no)	
	$(ECHO_NOTHING)cd $(GNUSTEP_BUILD_DIR); \
	$(MKDIRS) ./$(GNUSTEP_OBJ_DIR_NAME)$(END_ECHO)
else
	$(ECHO_NOTHING)cd $(GNUSTEP_BUILD_DIR); \
	$(MKDIRS) ./$(GNUSTEP_OBJ_DIR_NAME); \
	$(RM_LN_S) obj; \
	$(LN_S) ./$(GNUSTEP_OBJ_DIR_NAME) obj$(END_ECHO)
endif

endif
# rules.make loaded
