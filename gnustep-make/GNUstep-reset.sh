#! /bin/echo This file must be sourced inside (ba)sh using: .
#
#   GNUstep-reset.sh
#
#   Shell script resetting the GNUstep environment variables
#
#   Copyright (C) 2002 Free Software Foundation, Inc.
#
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

# This file is used to reset your environment.  This is needed if you
# want to change LIBRARY_COMBO.  You first reset your environment, then
# set a new LIBRARY_COMBO variable, then source GNUstep.sh again.

# This file resets variables in reverse order as they are set in the
# GNUstep.sh file.

# This function resets a path.
# It takes two arguments: the name of the path variable to reset,
# and a path fragment which is used to make our guess at what should
# be removed more accurate.  All paths beginning with GNUSTEP_SYSTEM_ROOT, 
# GNUSTEP_LOCAL_ROOT, GNUSTEP_NETWORK_ROOT and GNUSTEP_USER_ROOT 
# followed by the specified path fragment are removed from the path
# variable.  All other paths are kept unchanged.
function reset_path 
{
  # Declare local variables
  local original_path tmp_IFS temp_path dir gnustep_dir found

  # NB: We need to use eval because we want to access a variable
  # whose name is another variable!
  original_path=$(eval echo \$$1)
  tmp_IFS="$IFS"
  IFS=:
  temp_path=
  # Loop on the paths
  for dir in $original_path; do
    # For each of them, keep it only if it's not beginning with
    # a path in GNUSTEP_PATHLIST as prefix
    found=no;
    for gnustep_dir in $GNUSTEP_PATHLIST; do
      if [ -n "$gnustep_dir$2" ]; then
        case "$dir" in
          $gnustep_dir$2*)  found=yes; break;;
          *);;
        esac;
      fi;
    done;
    if [ "$found" = "no" ]; then
      if [ -z "$temp_path" ]; then
        temp_path="$dir"
      else
        temp_path="$temp_path:$dir"
      fi;
    fi
  done
  IFS="$tmp_IFS"

  # Not set the path variable.
  eval "$1=\$temp_path"
  # Export it only if non empty, otherwise remove it completely from
  # the shell environment.
  temp_path=`eval echo \$"$1"`
  if [ -z "$temp_path" ]; then
    eval "unset $1"
  else
    eval "export $1"
  fi
}

reset_path CLASSPATH /Library/Libraries/Java
reset_path GUILE_LOAD_PATH /Library/Libraries/Guile
reset_path LD_LIBRARY_PATH /Library/Libraries
reset_path DYLD_LIBRARY_PATH /Library/Libraries
reset_path DYLD_FRAMEWORK_PATH /Library/Frameworks
reset_path PATH /Tools

# Make sure we destroy the reset_path function after using it - we don't
# want to pollute the environment with it.
unset -f reset_path

unset GNUSTEP_PATHLIST
unset GNUSTEP_USER_ROOT
unset GNUSTEP_HOST_OS
unset GNUSTEP_HOST_VENDOR
unset GNUSTEP_HOST_CPU
unset GNUSTEP_HOST
unset GNUSTEP_NETWORK_ROOT
unset GNUSTEP_LOCAL_ROOT
unset GNUSTEP_MAKEFILES
unset GNUSTEP_FLATTENED
unset GNUSTEP_SYSTEM_ROOT
unset GNUSTEP_ROOT
unset LIBRARY_COMBO

unset GNUSTEP_CONFIG_FILE
unset GNUSTEP_USER_CONFIG_FILE
unset GNUSTEP_USER_DIR
unset GNUSTEP_USER_DEFAULTS_DIR
