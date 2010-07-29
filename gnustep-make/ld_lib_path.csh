#!/bin/csh
#
#   ld_lib_path.csh
#
#   Set up the LD_LIBRARY_PATH (or similar env variable for your system)
#
#   Copyright (C) 1998 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
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

# The first (and only) parameter to this script is the canonical
# operating system name.

if ( "$GNUSTEP_FLATTENED" == "" ) then
  set last_path_part="Library/Libraries/${GNUSTEP_HOST_CPU}/${GNUSTEP_HOST_OS}/${LIBRARY_COMBO}"
  set tool_path_part="Library/Libraries/${GNUSTEP_HOST_CPU}/${GNUSTEP_HOST_OS}"
else
  set last_path_part="Library/Libraries"
  set tool_path_part="Library/Libraries"
endif

set host_os=${GNUSTEP_HOST_OS}

if ( "${host_os}" == "" ) then
  set host_os=${1}
endif

set lib_paths="${GNUSTEP_USER_ROOT}/${last_path_part}:${GNUSTEP_USER_ROOT}/${tool_path_part}:${GNUSTEP_LOCAL_ROOT}/${last_path_part}:${GNUSTEP_LOCAL_ROOT}/${tool_path_part}:${GNUSTEP_NETWORK_ROOT}/${last_path_part}:${GNUSTEP_NETWORK_ROOT}/${tool_path_part}:${GNUSTEP_SYSTEM_ROOT}/${last_path_part}:${GNUSTEP_SYSTEM_ROOT}/${tool_path_part}"

set last_path_part="Library/Frameworks"

set fw_paths="${GNUSTEP_USER_ROOT}/${last_path_part}:${GNUSTEP_LOCAL_ROOT}/${last_path_part}:${GNUSTEP_NETWORK_ROOT}/${last_path_part}:${GNUSTEP_SYSTEM_ROOT}/${last_path_part}"

switch ( "${host_os}" )

  case *nextstep4* :
    if ( $?DYLD_LIBRARY_PATH == 0 ) then
	setenv DYLD_LIBRARY_PATH "${lib_paths}"
    else if ( { (echo "${DYLD_LIBRARY_PATH}" | fgrep -v "${lib_paths}" >/dev/null) } ) then
	setenv DYLD_LIBRARY_PATH "${lib_paths}:${DYLD_LIBRARY_PATH}"
    endif
    if ( $?additional_lib_paths == 1) then
      foreach dir (${additional_lib_paths})
	set additional="${additional}${dir}:"
      end
    endif

    if ( "${?additional}" == "1" ) then
      if ( { (echo "${DYLD_LIBRARY_PATH}" | fgrep -v "${additional}" >/dev/null) } ) then
       setenv DYLD_LIBRARY_PATH="${additional}${DYLD_LIBRARY_PATH}"
      endif
    endif
    breaksw

  case *darwin* :
    if ( $?DYLD_LIBRARY_PATH == 0 ) then
	setenv DYLD_LIBRARY_PATH "${lib_paths}"
    else if ( { (echo "${DYLD_LIBRARY_PATH}" | fgrep -v "${lib_paths}" >/dev/null) } ) then
	setenv DYLD_LIBRARY_PATH "${lib_paths}:${DYLD_LIBRARY_PATH}"
    endif
    if ( $?additional_lib_paths == 1) then
      foreach dir (${additional_lib_paths})
	set additional="${additional}${dir}:"
      end
    endif

    if ( "${?additional}" == "1" ) then
      if ( { (echo "${DYLD_LIBRARY_PATH}" | fgrep -v "${additional}" >/dev/null) } ) then
       setenv DYLD_LIBRARY_PATH="${additional}${DYLD_LIBRARY_PATH}"
      endif
    endif
    
# The code below has been temporarily removed, because...
# Frameworks in GNUstep-make are supported by creating a link like
# 
#   Libraries/libMyFramework.dylib ->
#      Frameworks/MyFramework.framework/Versions/Current/libMyFramework.dylib,
#
# to mitigate the fact that FSF GCC does not support a -framework flag.
#
# On Darwin, however, we partially emulate -framework by setting the
# "install_name" to the framework name during linking. The dynamic
# linker (dyld) is smart enough to find the framework under this name,
# but only if DYLD_FRAMEWORK_PATH is set (unless we set the
# "install_name" to an absolute path, which we don't). We'd really like
# to fully support -framework, though.
#
# Use otool -L MyApplication.app/MyApplication, for instance, to see
# how the shared libraries/frameworks are linked.
#
#    if [ "$LIBRARY_COMBO" = "apple-apple-apple" -o \
#         "$LIBRARY_COMBO" = "apple" ]; then

    unset additional

    if ( $?DYLD_FRAMEWORK_PATH == 0 ) then
      setenv DYLD_FRAMEWORK_PATH "${fw_paths}"
    else if ( { (echo "${DYLD_FRAMEWORK_PATH}" | fgrep -v "${fw_paths}" >/dev/null) } ) then
      setenv DYLD_FRAMEWORK_PATH "${fw_paths}:${DYLD_FRAMEWORK_PATH}"
    endif
    if ( $?additional_framework_paths == 1) then
      foreach dir (${additional_framework_paths})
        set additional="${additional}${dir}:"
      end
    endif

    if ( "${?additional}" == "1" ) then
      if ( { (echo "${DYLD_FRAMEWORK_PATH}" | fgrep -v "${additional}" >/dev/null) } ) then
        setenv DYLD_FRAMEWORK_PATH="${additional}${DYLD_FRAMEWORK_PATH}"
      endif
    endif
    breaksw

  case *hpux* :
    if ( $?SHLIB_PATH == 0 ) then
	setenv SHLIB_PATH "${lib_paths}"
    else if ( { (echo "${SHLIB_PATH}" | fgrep -v "${lib_paths}" >/dev/null) } ) then
	setenv SHLIB_PATH "${lib_paths}:${SHLIB_PATH}"
    endif
    if ( $?additional_lib_paths == 1) then
      foreach dir (${additional_lib_paths})
	set additional="${additional}${dir}:"
      end
    endif

    if ( "${?additional}" == "1" ) then
      if ( { (echo "${SHLIB_PATH}" | fgrep -v "${additional}" >/dev/null) } ) then
       setenv SHLIB_PATH="${additional}${SHLIB_PATH}"
      endif
    endif

    if ( $?LD_LIBRARY_PATH == 0 ) then
	setenv LD_LIBRARY_PATH "${lib_paths}"
    else if ( { (echo "${LD_LIBRARY_PATH}" | fgrep -v "${lib_paths}" >/dev/null) } ) then
	setenv LD_LIBRARY_PATH "${lib_paths}:${LD_LIBRARY_PATH}"
    endif

    if ( $?additional_lib_paths == 1) then
      foreach dir (${additional_lib_paths})
	set additional="${additional}${dir}:"
      end
    endif

    if ( "${?additional}" == "1" ) then
      if ( { (echo "${LD_LIBRARY_PATH}" | fgrep -v "${additional}" >/dev/null) } ) then
       setenv LD_LIBRARY_PATH="${additional}${LD_LIBRARY_PATH}"
      endif
    endif
    breaksw

  case * :
    if ( $?LD_LIBRARY_PATH == 0 ) then
	setenv LD_LIBRARY_PATH "${lib_paths}"
    else if ( { (echo "${LD_LIBRARY_PATH}" | fgrep -v "${lib_paths}" >/dev/null) } ) then
	setenv LD_LIBRARY_PATH "${lib_paths}:${LD_LIBRARY_PATH}"
    endif
    if ( $?additional_lib_paths == 1) then
      foreach dir (${additional_lib_paths})
	set additional="${additional}${dir}:"
      end
    endif

    if ( "${?additional}" == "1" ) then
      if ( { (echo "${LD_LIBRARY_PATH}" | fgrep -v "${additional}" >/dev/null) } ) then
       setenv LD_LIBRARY_PATH="${additional}${LD_LIBRARY_PATH}"
      endif
    endif
    breaksw

endsw

unset tool_path_part last_path_part host_os additional dir lib_paths fw_paths

