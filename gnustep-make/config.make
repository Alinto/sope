#
#   config.make.in
#
#   All of the settings required by the makefile package
#   that are determined by configure.
#
#   Copyright (C) 1997-2005 Free Software Foundation, Inc.
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

#
# The GNUstep Make Package Version
#
GNUSTEP_MAKE_MAJOR_VERSION=1
GNUSTEP_MAKE_MINOR_VERSION=13
GNUSTEP_MAKE_SUBMINOR_VERSION=0
GNUSTEP_MAKE_VERSION=1.13.0

#
# Binary and compile tools
#
CC       = gcc
OPTFLAG  = -g -O2
OBJCFLAGS= 
CPPFLAGS = 
CPP      = gcc -E

EXEEXT = 
OEXT   = .o
LIBEXT = .a

LN_S = ln -s

# This is the best we can do given the current autoconf, which only
# returns LN_S
ifeq ($(LN_S), ln -s)
  HAS_LN_S = yes
else
  HAS_LN_S = no
endif

# Special case - on mingw32, autoconf sets LN_S to 'ln -s', but then
# that does a recursive copy (ie, cp -r).
ifeq (linux-gnu,mingw32)
  HAS_LN_S = no
endif
# Special case - on cygwin, autoconf sets LN_S to 'ln -s', but then
# that does a recursive copy (ie, cp -r).
ifeq (linux-gnu,cygwin)
  HAS_LN_S = no
endif 



# This is used to remove an existing symlink before creating a new
# one.  We don't trust 'ln -s -f' as it's unportable so we remove
# manually the existing symlink (if any) before creating a new one.
# If symlinks are supported on the platform, RM_LN_S is just 'rm -f';
# if they are not, we assume they are copies (like cp -r) and we go
# heavy-handed with 'rm -Rf'.  Note - this code might need rechecking
# for the case where LN_S = 'ln', if that ever happens on some
# platforms.
ifeq ($(HAS_LN_S), yes)
  RM_LN_S = rm -f
  FRAMEWORK_VERSION_SUPPORT = yes
else
  RM_LN_S = rm -Rf
  FRAMEWORK_VERSION_SUPPORT = no
endif

LD = $(CC)
LDOUT =
LDFLAGS =  

AR      = ar
AROUT   =
ARFLAGS = rc
RANLIB  = ranlib

DLLTOOL = 

# NB: These variables are defined here only so that they can be
# overridden on the command line (so you can type 'AWK=mawk make' to
# use a different awk for that particular run of make).  We should
# *NOT* set them to the full path of these tools at configure time,
# because otherwise when you change/update the tools you would need to
# reconfigure and reinstall gnustep-make!  We can normally assume that
# typing 'awk' and 'sed' on the command line cause the preferred awk
# and sed programs on the system to be used.  Hardcoding the full path
# (or the name) of the specific awk or sed program on this sytem here
# would make it lot more inflexible.  In other words, the following
# definitions should remain like in 'AWK = awk' on all systems.
AWK             = awk
SED             = sed
YACC            = yacc
BISON           = bison
FLEX            = flex
LEX             = lex
CHOWN           = chown
STRIP           = strip

INSTALL		= /usr/bin/install -c
INSTALL_PROGRAM	= ${INSTALL}
INSTALL_DATA	= ${INSTALL} -m 644
TAR		= tar
MKDIRS		= $(GNUSTEP_MAKEFILES)/mkinstalldirs

# Darwin specific flags
CC_CPPPRECOMP  = no
CC_BUNDLE      = yes

# The default library combination
default_library_combo = gnu-fd-nil

# Backend bundle
BACKEND_BUNDLE=yes

#
# Do threading stuff.
#
# Warning - the base library's configure.in will extract the thread
# flags from the following line using grep/sed - so if you change the
# following lines you *need* to update the base library configure.in
# too.
#
ifndef objc_threaded
  objc_threaded:=-lpthread
endif

# Any user specified libs
CONFIG_SYSTEM_INCL=
CONFIG_SYSTEM_LIBS = 
CONFIG_SYSTEM_LIB_DIR = 

#
# Whether the C/ObjC/C++ compiler supports auto-dependencies
# (generating dependencies of the object files from the include files
# used to compile them) via -MMD -MP flags
#
AUTO_DEPENDENCIES = yes

#
# Whether the ObjC compiler supports precompiling headers.
#
PRECOMPILED_HEADERS = @PRECOMPILED_HEADERS@

#
# Whether the ObjC compiler supports native ObjC exceptions via
# @try/@catch/@finally/@throw.
#
USE_OBJC_EXCEPTIONS = no

#
# Location of GNUstep's config file for this installation
#
# Warning - the base library's configure.in will extract the GNUstep
# config file location from the following line using grep/sed - so if
# you change the following lines you *need* to update the base library
# configure.in too.
#
# PS: At run-time, this can be overridden on the command-line, or
# via an environment variable.
ifeq ($(GNUSTEP_CONFIG_FILE),)
GNUSTEP_CONFIG_FILE = /root/src/SOPE-4.7/.gsmake/GNUstep.conf
endif

#
# Now we set up the environment and everything by reading the GNUstep
# configuration file(s).
#

# These are the defaults value ... they will be used only if they are
# not set in the config files (or on the command-line or in
# environment).
GNUSTEP_SYSTEM_ROOT = /root/src/SOPE-4.7/.gsmake
GNUSTEP_LOCAL_ROOT = /root/src/SOPE-4.7/.gsmake
GNUSTEP_NETWORK_ROOT = /root/src/SOPE-4.7/.gsmake
GNUSTEP_USER_DIR = GNUstep

# This includes the GNUstep configuration file, but only if it exists
-include $(GNUSTEP_CONFIG_FILE)

# FIXME: determining GNUSTEP_HOME
GNUSTEP_HOME = $(HOME)

# Read the user configuration file ... unless it is disabled (ie, set
# to an empty string)
ifneq ($(GNUSTEP_USER_CONFIG_FILE),)

 # FIXME - Checking for relative vs. absolute paths!
 ifneq ($(filter /%, $(GNUSTEP_USER_CONFIG_FILE)),)
  # Path starts with '/', consider it absolute
  -include $(GNUSTEP_USER_CONFIG_FILE)
 else
  # Path does no start with '/', try it as relative
  -include $(GNUSTEP_HOME)/$(GNUSTEP_USER_CONFIG_FILE)
 endif 

endif

GNUSTEP_FLATTENED = yes

#
# Set GNUSTEP_USER_ROOT from GNUSTEP_USER_DIR; GNUSTEP_USER_ROOT is
# the variable used in practice
#
ifneq ($(filter /%, $(GNUSTEP_USER_DIR)),)
 # Path starts with '/', consider it absolute
 GNUSTEP_USER_ROOT = $(GNUSTEP_USER_DIR)
else
 # Path does no start with '/', try it as relative
 GNUSTEP_USER_ROOT = $(GNUSTEP_HOME)/$(GNUSTEP_USER_DIR)
endif 

# If multi-platform support is disabled, just use the hardcoded cpu,
# vendor and os determined when gnustep-make was configured.  The
# reason using the hardcoded ones might be better is that config.guess
# and similar scripts might even require compiling test files to
# determine the platform - which is horribly slow (that is done in
# names.make if GNUSTEP_HOST is not yet set at that stage).  To
# prevent this problem, unless we were configured to determine the
# platform at run time, by default we use the hardcoded values of
# GNUSTEP_HOST*.

ifeq ("","")
  GNUSTEP_HOST = powerpc-unknown-linux-gnu
  GNUSTEP_HOST_CPU = powerpc
  GNUSTEP_HOST_VENDOR = unknown
  GNUSTEP_HOST_OS = linux-gnu
endif
