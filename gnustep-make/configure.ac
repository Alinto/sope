#
#   configure.ac
#
#   Copyright (C) 1997-2004 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#	     Ovidiu Predescu <ovidiu@net-community.com>
#   Rewrite: Adam Fedor <fedor@gnu.org>
#            Nicola Pero <n.pero@mi.flashnet.it>
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
AC_INIT
AC_PREREQ(2.57)
AC_CONFIG_SRCDIR([application.make])
AC_CONFIG_HEADER(config.h)

#--------------------------------------------------------------------
# Setup the library combination
#--------------------------------------------------------------------
targetArgument=${target}
AC_PROG_CC
AC_PROG_CPP
AC_CANONICAL_TARGET([])

AC_MSG_CHECKING(for library combo)
AC_ARG_WITH(library-combo,[
--with-library-combo
   Define the default "library combo".  The library combo is a string
   of the form aaa-bbb-ccc where 'aaa' is the Objective-C runtime
   library to use (examples are 'gnu' and 'apple'), 
   'bbb' is the Foundation library to use (examples are 'gnu' for
   gnustep-base, and 'apple' for Apple Cocoa FoundationKit),
   and 'ccc' is the ApplicationKit to use (examples are 'gnu'
   for gnustep-gui and 'apple' for Apple Cocoa AppKit).  Use this 
   option if you want to force a different default library combo than 
   the one that would be used by default.  For example, on Darwin GNUstep
   will automatically use the Apple Objective-C frameworks by
   default (library-combo=apple-apple-apple); if you are planning 
   on installing and using gnustep-base on there, you would need 
   to use --with-library-combo=gnu-gnu-gnu instead.  Please notice
   that if --disable-flattened is used, gnustep-make can have fat
   binaries that support multiple library combos.  In that case,
   this flag will only configure the default one, but you can still
   use other ones at run-time.
],
ac_cv_library_combo=$withval,
ac_cv_library_combo=$ac_cv_library_combo
)

if test "$ac_cv_library_combo" = "" -o "$ac_cv_library_combo" = "no"; then
  case "$host_os" in
    darwin*)   ac_cv_library_combo=apple-apple-apple ;;
    nextstep4) ac_cv_library_combo=nx-nx-nx          ;;
    openstep4) ac_cv_library_combo=nx-nx-nx          ;;
    *)         ac_cv_library_combo=gnu-gnu-gnu       ;;
  esac
fi

case "$ac_cv_library_combo" in
  apple) ac_cv_library_combo=apple-apple-apple ;;
  gnu)   ac_cv_library_combo=gnu-gnu-gnu ;;
  nx)    ac_cv_library_combo=nx-nx-nx ;;
esac

AC_SUBST(ac_cv_library_combo)
AC_MSG_RESULT($ac_cv_library_combo)

OBJC_RUNTIME_LIB=`echo $ac_cv_library_combo | awk -F- '{print $1}'`

#--------------------------------------------------------------------
# Check if we are using Apple cc
#--------------------------------------------------------------------
cc_cppprecomp=0
cc_byndle=0
AC_MSG_CHECKING([for apple compiler flags])
cc_cppprecomp=`${CC} -no-cpp-precomp 2>&1 | grep -c "unrecognized"`
cc_bundle=`${CC} -bundle 2>&1 | grep -c "couldn"`
# 0 means we have the flag
if test $cc_cppprecomp = 0; then
  cc_cppprecomp=yes
else
  cc_cppprecomp=no
fi
if test $cc_bundle = 0; then
  cc_bundle=yes
else
  cc_bundle=no
fi
AC_MSG_RESULT($cc_bundle)
AC_SUBST(cc_cppprecomp)
AC_SUBST(cc_bundle)

#--------------------------------------------------------------------
# specific target_os options
#--------------------------------------------------------------------
case "$target_os" in
  freebsd* | openbsd* )	
	        INCLUDES="$INCLUDES -I/usr/local/include"
		LIB_DIR="$LIB_DIR -L/usr/local/lib";;
  netbsd*)	INCLUDES="$INCLUDES -I/usr/pkg/include"
		LIB_DIR="$LIB_DIR -Wl,-R/usr/pkg/lib -L/usr/pkg/lib";;
esac

#--------------------------------------------------------------------
# Determine the host, build, and target systems
#--------------------------------------------------------------------
case $host_os in
  *cygwin*  )
	MINGW32=no
	CYGWIN=yes
	MSWIND=yes;;
  *mingw32* )
	MINGW32=yes
	CYGWIN=yes
	MSWIND=yes;;
          * )
	MINGW32=no
	CYGWIN=no
	MSWIND=no;;
esac
AC_SUBST(CYGWIN)

AC_EXEEXT
AC_OBJEXT
if test "$MINGW32" = yes; then
  echo "hosted on mingw32 .."
  export INSTALL="install -p"
  export SHELL=sh
  export CC=${CC:-gcc}
  export AR=${AR:-ar}
  export RANLIB=${RANLIB:-ranlib}
  export DLLTOOL=${DLLTOOL:-dlltool}
elif test "$CYGWIN" = yes; then
  echo "hosted on cygwin .."
  export CC=${CC:-gcc}
  export AR=${AR:-ar}
  export RANLIB=${RANLIB:-ranlib}
  export DLLTOOL=${DLLTOOL:-dlltool}
fi

#--------------------------------------------------------------------
# Find the binary and compile tools
#--------------------------------------------------------------------
if test "x$target" != "x$host"; then
  echo "cross compiling from $host to $target .."
  cross_compiling="yes"
  AC_CHECK_PROG(CC,      "${targetArgument}-gcc",     dnl
                         "${targetArgument}-gcc",     gcc)
  AC_CHECK_PROG(RANLIB,  "${targetArgument}-ranlib",  dnl
                         "${targetArgument}-ranlib",  ranlib)
  AC_CHECK_PROG(AR,      "${targetArgument}-ar",      dnl
                         "${targetArgument}-ar",      ar)
  AC_CHECK_PROG(DLLTOOL, "${targetArgument}-dlltool", dnl
                         "${targetArgument}-dlltool", dlltool)
else
  AC_CHECK_PROG(AR,      ar,      ar)
  AC_CHECK_PROG(DLLTOOL, dlltool, dlltool)
  AC_PROG_RANLIB
fi

AC_PROG_INSTALL
AC_PROG_LN_S([])

AC_CHECK_PROGS(TAR, gnutar gtar, tar)
AC_ARG_WITH(tar,[
--with-tar
   Set the name of the tar program to use.  Use this option if the
   default choice does not work for you.
],
  TAR="$withval",)

AC_CHECK_PROG(CHOWN, chown, chown, none)
if test "$MINGW32" = no; then
  if test "$CHOWN" = "none"; then
    AC_MSG_ERROR("Could not find chown.");
  fi
fi

#-------------------------------------------------------------------
# GNUstep specific options follow
#-------------------------------------------------------------------

#---------------------------------------------------------------------
# Location of the GNUstep.conf config file (--with-config-file)
#---------------------------------------------------------------------
AC_MSG_CHECKING([for GNUstep configuration file to use])
AC_ARG_WITH(config-file,[
--with-config-file=PATH
   Set the path of the system GNUstep config file.  Use this option 
   if you want to have the GNUstep config file in a non-standard place.
   Example: --with-config-file=/usr/GNUstep/GNUstep.conf
],
  GNUSTEP_CONFIG_FILE="$withval",)
if test "$GNUSTEP_CONFIG_FILE" = "" -o "$GNUSTEP_CONFIG_FILE" = "no"; then
  case "$target_os" in
    freebsd* | openbsd* ) GNUSTEP_CONFIG_FILE=/usr/etc/GNUstep.conf ;;
    netbsd* )             GNUSTEP_CONFIG_FILE=/usr/pkg/etc/GNUstep.conf ;;
    mingw32* )	    GNUSTEP_CONFIG_FILE=/c/GNUstep/GNUstep.conf-dev ;;
    *)	            GNUSTEP_CONFIG_FILE=/etc/GNUstep/GNUstep.conf ;;
  esac
fi
if echo "$GNUSTEP_CONFIG_FILE" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_CONFIG_FILE'"
  echo "Please try again using --with-config-file= to specify a valid path."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_CONFIG_FILE)
AC_SUBST(GNUSTEP_CONFIG_FILE)

#---------------------------------------------------------------------
# Now read/import the existing configuration file, if any
#---------------------------------------------------------------------

# Reading/importing the existing configuration file is good as a
# default because it means that you don't have to type in your
# GNUSTEP_SYSTEM_ROOT, GNUSTEP_LOCAL_ROOT, etc. settings every time
# you configure gnustep-make. (please note we only read the
# system-wide one, not the user one.  Reason being that the settings
# we read will be used to generate the new system-wide one, while the
# user one will be left untouched).

# It can be annoying in certain cases though; this option lets you
# turn it off
AC_MSG_CHECKING([if we should import an existing configuration file])
AC_ARG_ENABLE(importing-config-file, [
--disable-importing-config-file
   Disable importing the existing system GNUstep configuration file.
   Use this option to prevent an existing configuration file from being
   parsed and used when configure is being run.
], 
  ac_cv_importing_config_file=$enableval,
  ac_cv_importing_config_file="yes")

# If importing the file is disabled, don't import it.
if test "$ac_cv_importing_config_file" = "no"; then
  AC_MSG_RESULT([no: disabled from the command-line])
else

 # Check that the file exists
 if test ! -f "$GNUSTEP_CONFIG_FILE"; then
  AC_MSG_RESULT([no: file "$GNUSTEP_CONFIG_FILE" does not exist])
 else
  AC_MSG_RESULT([yes: trying to import "$GNUSTEP_CONFIG_FILE"])
  AC_MSG_NOTICE([If this fails, please run configure again with the --disable-importing-config-file option])
  . "$GNUSTEP_CONFIG_FILE"
 fi
fi

#--------------------------------------------------------------------
# Important - from now on, any variable that is set in the
# configuration file (eg, GNUSTEP_SYSTEM_ROOT) could already have a
# value that we have imported from the previous file.  ./configure
# command line options should override those values, but otherwise we
# should keep them!
#
# Those could also be env variables, which is really a backwards
# compatibility hack that won't necessarily be kept in the future!
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Process --prefix
#--------------------------------------------------------------------

#
# In practice,
#
# ./configure --prefix=/usr/GNUstep
#
# is equivalent to:
#
# ./configure --with-system-root=/usr/GNUstep/System
#             --with-local-root=/usr/GNUstep/Local
#
# plus it has the side-effect that a config.site will be loaded by
# ./configure from $prefix/share/config.site, if it exists.  Our
# config.site is in $prefix/System/share/config.site though, so it
# won't be found.  It doesn't really matter though, as the config.site
# is irrelevant for us in this context.
#

# Please note that AC_PREFIX_DEFAULT will not appear in this position
# in the generated configure file; it will appear at the very
# beginning.  So we can't check for GNUSTEP_SYSTEM_ROOT or anything
# similar in the implementation of AC_PREFIX_DEFAULT because we will
# not have read GNUstep.conf yet ...  

# PS: This is the default GNUSTEP_ROOT that is used when installing
# GNUstep with no other indication.  Test for the C: directory, which
# means we're on Windows
AC_PREFIX_DEFAULT(`if test -d C: ; then
    echo C:/GNUstep;
  else
    echo /usr/GNUstep ;
  fi`)

#
# GNUSTEP_ROOT is only used to set default values for
# GNUSTEP_SYSTEM_ROOT and GNUSTEP_LOCAL_ROOT if they are not set in
# config file or as a command-line argument.
#
if test "x$prefix" = "xNONE"; then
  GNUSTEP_ROOT="$ac_default_prefix" ;
else
  GNUSTEP_ROOT="$prefix";

  # Set the values for all those variables ovverriding anything read
  # from the configuration file or inherited from the environment.
  # The --prefix=xxx option should overwrite those.  Please notice
  # that the --with-system-root=xxx (and similar) options are
  # processed later as overwrite --prefix=xxx in their specific area.
  GNUSTEP_SYSTEM_ROOT="$GNUSTEP_ROOT/System";
  GNUSTEP_LOCAL_ROOT="$GNUSTEP_ROOT/Local";
  GNUSTEP_NETWORK_ROOT="$GNUSTEP_LOCAL_ROOT";
fi

#--------------------------------------------------------------------
# Process --with-system-root
#--------------------------------------------------------------------
AC_MSG_CHECKING(for GNUSTEP_SYSTEM_ROOT to use)
AC_ARG_WITH(system-root,[
--with-system-root
   Set the GNUSTEP_SYSTEM_ROOT directory.  Use this option if you want 
   to have the GNUSTEP_SYSTEM_ROOT directory in a non-standard place.
   Example: --with-system-root=/usr/GNUstep/System
],
GNUSTEP_SYSTEM_ROOT="$withval",)
if test "$GNUSTEP_SYSTEM_ROOT" = "" -o "$GNUSTEP_SYSTEM_ROOT" = "no"; then 
  GNUSTEP_SYSTEM_ROOT="$GNUSTEP_ROOT/System"
fi
if echo "$GNUSTEP_SYSTEM_ROOT" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_SYSTEM_ROOT'"
  echo "Please try again using --with-system-root= to specify a valid path."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_SYSTEM_ROOT)
AC_SUBST(GNUSTEP_SYSTEM_ROOT)

#--------------------------------------------------------------------
# Process --with-local-root
#--------------------------------------------------------------------
AC_MSG_CHECKING(for GNUSTEP_LOCAL_ROOT to use)
AC_ARG_WITH(local-root,[
--with-local-root
   Set the GNUSTEP_LOCAL_ROOT directory.  Use this option if you want 
   to have the GNUSTEP_LOCAL_ROOT directory in a non-standard place.
   Example: --with-local-root=/usr/local/GNUstep/Local
],
GNUSTEP_LOCAL_ROOT="$withval",)
# If GNUSTEP_LOCAL_ROOT is explicitly set to 'no', we effectively disable it
# by setting it to be the same as GNUSTEP_SYSTEM_ROOT
if test "$GNUSTEP_LOCAL_ROOT" = "no"; then 
  GNUSTEP_LOCAL_ROOT="$GNUSTEP_SYSTEM_ROOT"
fi
if test "$GNUSTEP_LOCAL_ROOT" = ""; then 
  GNUSTEP_LOCAL_ROOT="$GNUSTEP_ROOT/Local"
fi
if echo "$GNUSTEP_LOCAL_ROOT" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_LOCAL_ROOT'"
  echo "Please try again using --with-local-root= to specify a valid path."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_LOCAL_ROOT)
AC_SUBST(GNUSTEP_LOCAL_ROOT)

#--------------------------------------------------------------------
# Process --with-network-root
#--------------------------------------------------------------------
AC_MSG_CHECKING(for GNUSTEP_NETWORK_ROOT to use)
AC_ARG_WITH(network-root,[
--with-network-root
   Set the GNUSTEP_NETWORK_ROOT directory.  Use this option if you 
   want to have the GNUSTEP_NETWORK_ROOT directory.  
   Example: --with-network-root=/usr/local/GNUstep/Network
],
GNUSTEP_NETWORK_ROOT="$withval",)
# By default we disable network root, by setting GNUSTEP_NETWORK_ROOT
# to be the same as GNUSTEP_LOCAL_ROOT.  GNUSTEP_NETWORK_ROOT is very
# rarely used, and most users prefer simpler systems with shorter
# paths and shorter command lines.  To turn on GNUSTEP_NETWORK_ROOT
# again, you can use the --with-network-root=xxx option; pass
# something like --with-network-root=/usr/GNUstep/Network on the
# configure command line.
if test "$GNUSTEP_NETWORK_ROOT" = "" -o "$GNUSTEP_NETWORK_ROOT" = "no"; then 
  GNUSTEP_NETWORK_ROOT="$GNUSTEP_LOCAL_ROOT"
fi
if echo "$GNUSTEP_NETWORK_ROOT" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_NETWORK_ROOT'"
  echo "Please try again using --with-network-root= to specify a valid path."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_NETWORK_ROOT)
AC_SUBST(GNUSTEP_NETWORK_ROOT)

#--------------------------------------------------------------------
# Process --with-user-config-file
#--------------------------------------------------------------------
AC_MSG_CHECKING(for user config file to use)
AC_ARG_WITH(user-config-file,[
--with-user-config-file
   Set the name of the user config file to use.  This can be 
   relative to the user's home directory if it is a relative path,
   or an absolute directory (the same for all users) if it is an
   absolute path.  Use '' if you want to disable user config files.
   The default is .GNUstep.conf if not specified.
   Example: --with-user-config-file=GNUstep/GNUstep.conf
],
GNUSTEP_USER_CONFIG_FILE="$withval",)
if test "$GNUSTEP_USER_CONFIG_FILE" = "" -o "$GNUSTEP_USER_CONFIG_FILE" = "no"; then 
  GNUSTEP_USER_CONFIG_FILE=".GNUstep.conf"
fi
if echo "$GNUSTEP_USER_CONFIG_FILE" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_USER_CONFIG_FILE'"
  echo "Please try again using --with-user-config-file= to specify a value."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_NETWORK_ROOT)
AC_MSG_RESULT($GNUSTEP_USER_CONFIG_FILE)
AC_SUBST(GNUSTEP_USER_CONFIG_FILE)

#--------------------------------------------------------------------
# Process --with-user-dir
#--------------------------------------------------------------------
AC_MSG_CHECKING(for user dir to use)
AC_ARG_WITH(user-dir,[
--with-user-dir
   Set the GNUSTEP_USER_DIR directory for all users.  This can be
   relative to the user's home directory if it is a relative path,
   or an absolute directory (the same for all users) if it is an
   absolute path.  Use this option if you want to have the 
   GNUSTEP_USER_DIR directory in a non default place for all users.
   The default is 'GNUstep'.
   Example: --with-user-dir='gnustep'
],
GNUSTEP_USER_DIR="$withval",)
if test "$GNUSTEP_USER_DIR" = "" -o "$GNUSTEP_USER_DIR" = "no"; then 
  GNUSTEP_USER_DIR="GNUstep"
fi
if echo "$GNUSTEP_USER_DIR" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_USER_DIR'"
  echo "Please try again using --with-user-dir= to specify a value."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_USER_DIR)
AC_SUBST(GNUSTEP_USER_DIR)

#--------------------------------------------------------------------
# Process --with-user-defaults-dir
#--------------------------------------------------------------------
AC_MSG_CHECKING(for user defaults dir to use)
AC_ARG_WITH(user-defaults-dir,[
--with-user-defaults-dir
   Set the GNUstep user defaults directory for all users.  This can be
   relative to the user's home directory if it is a relative path,
   or an absolute directory (the same for all users) if it is an
   absolute path.  Use this option if you want to have the 
   GNUSTEP_USER_DEFAULTS_DIR directory in a non default place for
   all users.  The default is 'GNUstep/Defaults'
   Example: --with-user-defaults-dir='GNUstep/Library/Defaults'
],
GNUSTEP_USER_DEFAULTS_DIR="$withval",)
if test "$GNUSTEP_USER_DEFAULTS_DIR" = "" -o "$GNUSTEP_USER_DEFAULTS_DIR" = "no"; then 
  GNUSTEP_USER_DEFAULTS_DIR="GNUstep/Defaults"
fi
if echo "$GNUSTEP_USER_DEFAULTS_DIR" | grep -q '[[ 	\\]]'
then
  echo "found a backslash or space (illegal) in '$GNUSTEP_USER_DEFAULTS_DIR'"
  echo "Please try again using --with-user-defaults-dir= to specify a value."
  if test "$MSWIND" = "yes"
  then
    echo "Please note that on windows you must use unix-style paths within"
    echo "the make package even though gnustep programs built in the mingw32"
    echo "environment use native paths throughout."
  fi
  exit 1
fi
AC_MSG_RESULT($GNUSTEP_USER_DEFAULTS_DIR)
AC_SUBST(GNUSTEP_USER_DEFAULTS_DIR)

#--------------------------------------------------------------------
# Setting up GNUSTEP_MAKEFILES
#--------------------------------------------------------------------
#
# Please note that we do an explicit check in preparation for the (not
# so far) future when this directory (like any other GNUstep
# directory, eg, Applications or Tools or Libraries) will be
# relocatable to anywhere you like.
#
AC_MSG_CHECKING(for GNUSTEP_MAKEFILES to use)
GNUSTEP_MAKEFILES="$GNUSTEP_SYSTEM_ROOT/Library/Makefiles"
AC_SUBST(GNUSTEP_MAKEFILES)
AC_MSG_RESULT($GNUSTEP_MAKEFILES)

#--------------------------------------------------------------------
# Setting up the install-sh script
#--------------------------------------------------------------------

# HOST_INSTALL is the name of the install program in config.make so set it up
# to point to the install-sh script in the GNUstep tree if no system install is
# found.
AC_SUBST(HOST_INSTALL)
if test "$INSTALL" = "$ac_install_sh"; then
  HOST_INSTALL="$GNUSTEP_MAKEFILES/$INSTALL"
else
  HOST_INSTALL="$INSTALL"
fi

#--------------------------------------------------------------------
# Is the system flattened?
#--------------------------------------------------------------------
AC_MSG_CHECKING(for flattened directory structure)
AC_ARG_ENABLE(flattened, [
--disable-flattened
   Disable flattened directory structure.  Use this option if you want
   to have support for multiple library combos and fat binaries.  A
   library combo specifies the Objective-C frameworks to use to compile
   a program, so having multiple library combos is only useful if you 
   have (or plan to have) multiple OpenStep-like Objective-C frameworks 
   installed on your machine, for example both the Apple Cocoa Objective-C 
   frameworks and the GNUstep frameworks.  Fat binaries allow you to
   have multiple versions for different CPUs and Operating Systems.  
   Please note that using the fat directory structure will not blend 
   easily with native filesystems and so if you want the non-flattened
   directory structure you probably want to install GNUstep using its 
   own default filesystem layout.  To switch between different 
   library-combos, you also need to source GNUstep.sh after
   setting the LIBRARY_COMBO environment variable.  Please refer to
   the documentation for more information on library-combos and fat
   binaries.
], 
  ac_cv_flattened=$enableval,
  ac_cv_flattened="undefined")

if test "$ac_cv_flattened" = "no"; then
  GNUSTEP_FLATTENED=;
else
  GNUSTEP_FLATTENED=yes;
fi
AC_SUBST(GNUSTEP_FLATTENED)

if test "$GNUSTEP_FLATTENED" = "yes"; then
  AC_MSG_RESULT(yes);
else
  AC_MSG_RESULT(no);
fi


#--------------------------------------------------------------------
# Is the system multi-platform?
#--------------------------------------------------------------------
#
# Multi-platform means that GNUstep.sh will determine the host
# platform (by running config.guess) each time that it is sourced.
# This is good if you are sharing your GNUstep.sh across your network
# (for example, mounting the makefiles via NFS), but it requires you
# to be able to run config.guess on your machine(s), which usually
# requires a development environment (compiler, libc etc).
#
# The default instead is not using multi-platform, which means the
# local host os, cpu and version is hardcoded in GNUstep.sh.  This
# works nicely for a single machine using this gnustep-make
# installation, and it works even if you don't have development
# packages (gcc, binutils, libc-dev etc) installed.  We had to make
# this the default after end-users (with no development packages
# installed) complained that binary packages wouldn't work (and the
# reason turned out to be that GNUstep.sh was running config.guess
# which was returning the wrong platform because the development
# tools needed/used to determine the platform were not available).
#
# Unless you know what you are doing, stick with the default, which is
# also much faster when sourcing GNUstep.sh.
#
AC_ARG_ENABLE(multi-platform, [
--enable-multi-platform
   Enable run-time multi-platform support.  If this option is enabled,
   then every time GNUstep.sh is run it will determine/guess the type
   of local host machine instead of using the hardcoded value.  Use
   this together with --disable-flattened if you have a single GNUstep
   installation with fat binaries that is being shared over the network
   by a variety of machines with different hardware and o/s.
], 
  ac_cv_multi_platform=$enableval,
  ac_cv_multi_platform="undefined")

if test "$ac_cv_multi_platform" = "yes"; then
  GNUSTEP_MULTI_PLATFORM=yes;
else
  GNUSTEP_MULTI_PLATFORM=;
fi
AC_SUBST(GNUSTEP_MULTI_PLATFORM)

#--------------------------------------------------------------------
# Build backend bundles (on by default)
#--------------------------------------------------------------------
AC_ARG_ENABLE(backend-bundle, [
--disable-backend-bundle
   Compile GUI backend as a library.  Use this option if the default
   compilation of the GUI backend as a bundle (loadable module) is
   not supported / does not work on your machine.
], 
  ac_cv_backend=$enableval,  
  ac_cv_backend="yes")

if test "$ac_cv_backend" = "yes"; then
  BACKEND_BUNDLE=yes;
else
  BACKEND_BUNDLE=;
fi
AC_SUBST(BACKEND_BUNDLE)

#--------------------------------------------------------------------
# Miscellaneous flags and setup
#--------------------------------------------------------------------

# Set location of GNUstep dirs for later use
if test "$GNUSTEP_FLATTENED" = yes; then
  GNUSTEP_LDIR="$GNUSTEP_SYSTEM_ROOT/Library/Libraries"
  GNUSTEP_HDIR="$GNUSTEP_SYSTEM_ROOT/Library/Headers"
else
  clean_target_os=`$srcdir/clean_os.sh $target_os`
  clean_target_cpu=`$srcdir/clean_cpu.sh $target_cpu`
  obj_dir="$clean_target_cpu/$clean_target_os"
  GNUSTEP_LDIR="$GNUSTEP_SYSTEM_ROOT/Library/Libraries/$obj_dir"
  GNUSTEP_HDIR="$GNUSTEP_SYSTEM_ROOT/Library/Headers/${ac_cv_library_combo}"
fi

# Check to see if the libobjc library is in our GNUSTEP_SYSTEM_ROOT.
# If so, there are probably other libraries that we want there also, so
# leave the proper includes in CPPFLAGS and LDFLAGS
AC_MSG_CHECKING(for custom shared objc library)
AC_CACHE_VAL(gs_cv_objc_libdir,
[dnl
gs_cv_objc_libdir=NONE
if test -f "$GNUSTEP_HDIR/objc/objc.h"; then
  if test -f "$GNUSTEP_LDIR/libobjc.a" -o -f "$GNUSTEP_LDIR/libobjc.so" -o -f "$GNUSTEP_LDIR/libobjc.dll.a" -o -f "$GNUSTEP_LDIR/libobjc-gnu.dylib"; then
    gs_cv_objc_libdir="$GNUSTEP_LDIR"
  else
    gs_cv_objc_libdir=NONE
  fi
fi
#gcc_shared_libobjc=`gcc -print-file-name=libobjc.so`
#if test -f "$gcc_shared_libobjc"; then
#  gs_cv_objc_libdir=`dirname $gcc_shared_libobjc`
#fi
])
AC_MSG_RESULT($gs_cv_objc_libdir)

# The following are needed to compile the test programs
if test "$gs_cv_objc_libdir" = "$GNUSTEP_LDIR"; then
  if test "$GNUSTEP_FLATTENED" = yes; then
    OBJC_CPPFLAGS="$CPPFLAGS $INCLUDES -I$GNUSTEP_SYSTEM_ROOT/Library/Headers"
  else
    OBJC_CPPFLAGS="$CPPFLAGS $INCLUDES -I$GNUSTEP_SYSTEM_ROOT/Library/Headers/${ac_cv_library_combo}"
  fi
  OBJC_LDFLAGS="$LDFLAGS $LIB_DIR -L$gs_cv_objc_libdir"
fi

# And the following to execute them
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$gs_cv_objc_libdir"
export LD_LIBRARY_PATH

#--------------------------------------------------------------------
# Miscellaneous headers (only used for compiling which_lib.c and user_home.c)
#--------------------------------------------------------------------
AC_HEADER_DIRENT
AC_CHECK_HEADERS(sys/param.h sys/file.h dir.h string.h stdlib.h sys/types.h dnl
		fcntl.h limits.h utime.h sys/stat.h pwd.h unistd.h ctype.h)
AC_CHECK_FUNCS(getpwnam getpwuid geteuid getlogin strchr)

#--------------------------------------------------------------------
# Check if libobjc was compiled with thread support.
#--------------------------------------------------------------------
OBJC_THREAD=
AC_ARG_WITH(thread-lib,[
--with-thread-lib
   Specify alternate thread library.  Use this flag if configure can
   not properly determine the thread library used by your libobjc.
],
OBJC_THREAD=$withval,
OBJC_THREAD=
)
if test "$OBJC_THREAD" = no; then
OBJC_THREAD=
fi


AC_MSG_CHECKING(whether objc has thread support)
saved_CFLAGS="$CFLAGS"
saved_LIBS="$LIBS"
CFLAGS="$CFLAGS -x objective-c -I$srcdir $OBJC_CPPFLAGS $OBJC_LDFLAGS"
if test "$OBJC_RUNTIME_LIB" = "gnu"; then
  CFLAGS="$CFLAGS -fgnu-runtime"
fi
if test "$OBJC_RUNTIME_LIB" = "nx"; then
  CFLAGS="$CFLAGS -DNeXT_RUNTIME"
fi
if test "$OBJC_RUNTIME_LIB" = "apple"; then
  CFLAGS="$CFLAGS -DNeXT_RUNTIME"
fi
if test "$OBJC_THREAD" != ""; then
  LIBS="-lobjc $LIBS $OBJC_THREAD"
  AC_TRY_RUN([#include "config_thread.m"], 
	objc_threaded="$OBJC_THREAD",
	objc_threaded="", objc_threaded="")
elif test "$host_os" = linux-gnu; then
  LIBS="-lobjc -lpthread"
  AC_TRY_RUN([#include "config_thread.m"], objc_threaded="-lpthread",
	objc_threaded="", objc_threaded="-lpthread")
elif test "`echo $host_os|sed 's/[[0-9]].*//'|sed s/elf//`" = freebsd; then
  LIBS="-pthread -lobjc"
  AC_TRY_RUN([#include "config_thread.m"], objc_threaded="-pthread",
       objc_threaded="", objc_threaded="-pthread")
  if test x"$objc_threaded" = x""; then
    LIBS="-lpthread -lobjc"
    AC_TRY_RUN([#include "config_thread.m"], objc_threaded="-lpthread",
	objc_threaded="", objc_threaded="-lpthread")
  fi
  if test x"$objc_threaded" = x""; then
    LIBS="-lobjc -lpcthread"
    AC_TRY_RUN([#include "config_thread.m"], objc_threaded="-lpcthread",
	objc_threaded="", objc_threaded="-lpcthread")
  fi
elif test "$MINGW32" = yes; then
  # Mingw doesn't need anything extra for threads
  LIBS="-lobjc $LIBS"
  AC_TRY_RUN([#include "config_thread.m"], 
	objc_threaded="works",
	objc_threaded="", objc_threaded="works")
else
  LIBS="-lobjc $LIBS"
  AC_TRY_RUN([#include "config_thread.m"], 
	objc_threaded="works",
	objc_threaded="", objc_threaded="")
  if test x"$objc_threaded" = x""; then
    LIBS="-lobjc $saved_LIBS -lpthread "
    AC_TRY_RUN([#include "config_thread.m"], 
    	objc_threaded="-lpthread", 
	objc_threaded="", objc_threaded="")
  fi
  if test x"$objc_threaded" = x""; then
    # Solaris, OpenBSD/sparc
    LIBS="-lobjc $saved_LIBS -lpthread -lposix4"
    AC_TRY_RUN([#include "config_thread.m"], 
    	objc_threaded="-lpthread -lposix4", 
	objc_threaded="", objc_threaded="")
  fi
  if test x"$objc_threaded" = x""; then
    LIBS="-lobjc $saved_LIBS -lthread "
    AC_TRY_RUN([#include "config_thread.m"], 
    	objc_threaded="-lthread", 
	objc_threaded="", objc_threaded="")
  fi
fi
if test x"$objc_threaded" = x""; then
  AC_MSG_RESULT(no)
else
  if test x"$objc_threaded" = x"works"; then
    objc_threaded=""
  fi
  AC_MSG_RESULT(yes: $objc_threaded)
fi
ac_cv_objc_threaded="$objc_threaded"
AC_SUBST(objc_threaded)
AC_SUBST(ac_cv_objc_threaded)

# Do not restore LIBS and CFLAGS yet as we need to test if the
# compiler supports native exceptions.

#--------------------------------------------------------------------
# Check if GCC supports -fobjc-exceptions, and if so, turn it on!
#--------------------------------------------------------------------

AC_ARG_ENABLE(native-objc-exceptions, [
--enable-native-objc-exceptions
   Use native Objective-C exceptions.  Use this option if you want
   to use the native Objective-C exception support (@try/@catch/@finally)
   provided by newer GCC compilers.
], 
USE_OBJC_EXCEPTIONS=$enableval,
USE_OBJC_EXCEPTIONS=no)

AC_MSG_CHECKING(whether we should use native ObjC exceptions)
if test x"$USE_OBJC_EXCEPTIONS" = x"yes"; then
  # What we want to do: set USE_OBJC_EXCEPTIONS to yes if we can compile
  # something with @try/@catch/@finally in it.
  if test ! ${GCC} = "yes" ; then
    USE_OBJC_EXCEPTIONS=no
    AC_MSG_RESULT(no: compiler isn't gcc)
  else
    CFLAGS="$CFLAGS -fobjc-exceptions"
    AC_RUN_IFELSE([[
#include <stdlib.h>
#include <objc/Object.h>

int main(int argc, char **argv)
{
	Object *o=nil;
	@try
	{
		o=[Object new];
		@throw o;
	}
	@catch (id foo)
	{
		if (o!=foo)
			return 1;
	}
	return 0;
}
  ]], USE_OBJC_EXCEPTIONS=yes, USE_OBJC_EXCEPTIONS=no)
    AC_MSG_RESULT($USE_OBJC_EXCEPTIONS)
  fi
  if test x$USE_OBJC_EXCEPTIONS = xno; then
    AC_MSG_NOTICE([Native objective-c exceptions were requested, but the compiler])
    AC_MSG_NOTICE([doesn't support them.])
    AC_MSG_ERROR([compiler doesn't support native objective-c exceptions])
  fi
else
  AC_MSG_RESULT(not requested by user)
fi

AC_SUBST(USE_OBJC_EXCEPTIONS)

# Restore LIBS and CFLAGS - we are going to compile C code in the next
# test.
LIBS="$saved_LIBS"
CFLAGS="$saved_CFLAGS"

#--------------------------------------------------------------------
# Check if compiler supports -MMD -MP to generate %.d files ...
#--------------------------------------------------------------------

AC_MSG_CHECKING(if the compiler supports autodependencies)

# What we want to do: set AUTO_DEPENDENCIES to yes if gcc => 3.x

if test ! ${GCC} = "yes" ; then
  AUTO_DEPENDENCIES=""
  PRECOMPILED_HEADERS=""
  AC_MSG_RESULT(no: it's not gcc)
else
  # Running gcc -dumpversion we get something like 2.95.4 or
  #  egcs-2.91.66 or 3.0.2 or 3.1 20011211
  # We want to discard anything but the major number.
  # Explanation of the regexp -
  # \(^[^0-9]*\) matches beginning of line and following non numeric chars
  # \([0-9][0-9]*\) matches 1 or more numeric chars (this is the 2^nd
  #  subpattern)
  # \([^0-9].*\) matches a non numeric char followed by anything
  # /\2/ replace the whole lot with the 2^nd subpattern
  gs_cv_gcc_major_version=`${CC} -dumpversion | sed "s/\([[^0-9]]*\)\([[0-9]][[0-9]]*\)\([[^0-9]].*\)/\2/"`;

  if test "${gs_cv_gcc_major_version}" -ge "3" ; then
    AUTO_DEPENDENCIES=yes
    AC_MSG_RESULT(yes: gcc major version is ${gs_cv_gcc_major_version})
  else
    AUTO_DEPENDENCIES=""
    PRECOMPILED_HEADERS=""
    AC_MSG_RESULT(no: gcc major version is ${gs_cv_gcc_major_version})
  fi
fi

AC_SUBST(AUTO_DEPENDENCIES)
AC_SUBST(PRECOMPILED_HEADERS)
AC_SUBST(INCLUDES)
AC_SUBST(LIB_DIR)
AC_SUBST(OBJCFLAGS)

#--------------------------------------------------------------------
# Shall we strip makefiles upon installation ?
#--------------------------------------------------------------------

# Stripping makefiles removes comments and newlines from them.  The
# resulting stripped makefiles execute around 5% faster on average.
# Too little for it to be worth for the common user who's more
# interested in the comments :-) so it's disabled by default.
AC_MSG_CHECKING(if we should strip makefiles after installation)
AC_ARG_ENABLE(strip-makefiles, [
--enable-strip-makefiles
   Enable stripping system makefiles after installation.  This will 
   speed up gnustep-make by about 5% (average), but will remove all 
   comments from the installed makefiles.  Those comments are quite
   useful if you are trying to find some information on how gnustep-make
   works (eg, if you're trying to locate a bug), and the performance
   gain is quite small, so you probably don't want to strip makefiles.
],
  ac_cv_strip_makefiles=$enableval,
  ac_cv_strip_makefiles="undefined")

if test "$ac_cv_strip_makefiles" = "yes"; then
  GNUSTEP_STRIP_MAKEFILES=strip;
  AC_MSG_RESULT(yes);
else
  GNUSTEP_STRIP_MAKEFILES=;
  AC_MSG_RESULT(no);
fi
AC_SUBST(GNUSTEP_STRIP_MAKEFILES)

#--------------------------------------------------------------------
# Disable updating the obsolete directory structure
#--------------------------------------------------------------------
gs_move_obsolete=yes
AC_ARG_ENABLE(move-obsolete,[
--disable-move-obsolete
   Disable moving obsolete dir structure.  This option will be 
   removed SOON as the dir structure was change more than 2 years ago! :-)
],
  gs_move_obsolete=$enableval,
  gs_move_obsolete=yes)

if test "$gs_move_obsolete" = "yes"; then
  GNUSTEP_MOVE_OBSOLETE=move_obsolete;
else
  GNUSTEP_MOVE_OBSOLETE=
  AC_MSG_NOTICE(Old GNUstep directories will not be moved)
fi
AC_SUBST(GNUSTEP_MOVE_OBSOLETE)

#--------------------------------------------------------------------
# Enable/disable precompiled headers
#--------------------------------------------------------------------
# TODO: replace with / add a check whether PCH works with the
#       compiler
gs_enable_pch=no
AC_MSG_CHECKING(if we should enable precompiled headers (pch))
AC_ARG_ENABLE(pch, 
[--enable-pch			Enable precompiled headers], 
  gs_enable_pch=$enableval,
  gs_enable_pch=no)

if test "$gs_enable_pch" = "yes"; then
  PRECOMPILED_HEADERS=yes
  AC_MSG_RESULT(yes);
else
  PRECOMPILED_HEADERS=
  AC_MSG_RESULT(no);
fi
AC_SUBST(PRECOMPILED_HEADERS)

#--------------------------------------------------------------------
# Record the version
#--------------------------------------------------------------------
AC_MSG_CHECKING(for the version of gnustep-make we are compiling)
. "$srcdir/Version"
AC_MSG_RESULT($GNUSTEP_MAKE_VERSION)
AC_SUBST(GNUSTEP_MAKE_VERSION)
AC_SUBST(GNUSTEP_MAKE_MAJOR_VERSION)
AC_SUBST(GNUSTEP_MAKE_MINOR_VERSION)
AC_SUBST(GNUSTEP_MAKE_SUBMINOR_VERSION)

#-------------------------------------------------------------------
# Record the 'clean' target_os, target_cpu and target_vendor
#-------------------------------------------------------------------
# This is just for efficiency, so that core/make/GNUmakefile does not
# have to compute clean_target_os from target_os (and similar) by
# running shell scripts each time you 'make' something inside
# gnustep-make.  We basically compute them once now, and cache them
# forever.  It is also used by GNUstep.sh when multi-platform is
# disabled.
clean_target_os=`$srcdir/clean_os.sh $target_os`
clean_target_cpu=`$srcdir/clean_cpu.sh $target_cpu`
clean_target_vendor=`$srcdir/clean_cpu.sh $target_vendor`
AC_SUBST(clean_target_os)
AC_SUBST(clean_target_cpu)
AC_SUBST(clean_target_vendor)
AC_SUBST(target)

#--------------------------------------------------------------------
# Produce the output files
#--------------------------------------------------------------------
AC_CONFIG_FILES([config.make openapp debugapp opentool 
executable.template GNUmakefile GNUstep.conf GNUstep.sh GNUstep.csh fixpath.sh
gnustep-make.spec])
AC_CONFIG_COMMANDS([default],
	[[chmod a+x openapp debugapp opentool fixpath.sh executable.template]],
	[[]])
AC_OUTPUT
