#! /bin/echo This file must be sourced inside csh using: source
#
#   GNUstep.csh.  Generated from GNUstep.csh.in by configure.
#
#   Shell initialization for the GNUstep environment.
#
#   Copyright (C) 1998-2005 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Adam Fedor <fedor@gnu.org>
#   Author:  Richard Frith-Macdonald <rfm@gnu.org>
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

#
# Set the GNUstep system root and local root
#

#
# Read our configuration files
#

# Determine the location of the system configuration file
if ( ! ${?GNUSTEP_CONFIG_FILE} ) then
  setenv GNUSTEP_CONFIG_FILE "/root/src/SOPE-4.7/.gsmake/GNUstep.conf"
endif

# Determine the location of the user configuration file
if ( ! ${?GNUSTEP_USER_CONFIG_FILE} ) then
  setenv GNUSTEP_USER_CONFIG_FILE ".GNUstep.conf"
endif

# Read the system configuration file
if ( -e "${GNUSTEP_CONFIG_FILE}" ) then
  #
  # Convert the config file from sh syntax to csh syntax, and execute it.
  #
  # We want to convert every line of the type ^xxx=yyy$ into setenv xxx yyy;
  # and ignore any other line.
  #
  # This sed expression will first delete all lines that don't match
  # the pattern ^[^#=][^#=]*=.*$ -- which means "start of line (^),
  # followed by a character that is not # and not = ([^#=]), followed
  # by 0 or more characters that are not # and not = ([^#=]*),
  # followed by a = (=), followed by some characters until end of the
  # line (.*$).  It will then replace each occurrence of the same
  # pattern (where the first and second relevant parts are now tagged
  # -- that's what the additional \(...\) do) with 'setenv \1 \2'.
  #
  # The result of all this is ... something that we want to execute!
  # We use eval to execute the results of `...`.
  #
  # Please note that ! must always be escaped in csh, which is why we
  # write \\!
  #
  # Also note that we add a ';' at the end of each setenv command so
  # that we can pipe all the commands through a single eval.
  #
  eval `sed -e '/^[^#=][^#=]*=.*$/\\!d' -e 's/^\([^#=][^#=]*\)=\(.*\)$/setenv \1 \2;/' "${GNUSTEP_CONFIG_FILE}"`
endif

# FIXME: determining GNUSTEP_HOME
set GNUSTEP_HOME = ~

# Read the user configuration file ... unless it is disabled (ie, set
# to an empty string)
if ( ${?GNUSTEP_USER_CONFIG_FILE} ) then
  switch ("${GNUSTEP_USER_CONFIG_FILE}")
   case /*: # An absolute path
     if ( -e "${GNUSTEP_USER_CONFIG_FILE}" ) then
      # See above for an explanation of the sed expression
      eval `sed -e '/^[^#=][^#=]*=.*$/\\!d' -e 's/^\([^#=][^#=]*\)=\(.*\)$/setenv \1 \2;/' "${GNUSTEP_USER_CONFIG_FILE}"``
     endif
     breaksw
   default: # Something else
     if ( -e "${GNUSTEP_HOME}/${GNUSTEP_USER_CONFIG_FILE}" ) then
       eval `sed -e '/^[^#=][^#=]*=.*$/\\!d' -e 's/^\([^#=][^#=]*\)=\(.*\)$/setenv \1 \2;/' "${GNUSTEP_HOME}/${GNUSTEP_USER_CONFIG_FILE}"`
     endif
     breaksw
   endsw
endif

# Now, set any essential variable (that is not already set) to the
# built-in values.
if ( ! ${?GNUSTEP_SYSTEM_ROOT} ) then
  setenv GNUSTEP_SYSTEM_ROOT "/root/src/SOPE-4.7/.gsmake"
endif

if ( ! ${?GNUSTEP_LOCAL_ROOT} ) then
  setenv GNUSTEP_LOCAL_ROOT "/root/src/SOPE-4.7/.gsmake"
endif

if ( ! ${?GNUSTEP_NETWORK_ROOT} ) then
  setenv GNUSTEP_NETWORK_ROOT "/root/src/SOPE-4.7/.gsmake"
endif


setenv GNUSTEP_FLATTENED "yes"
if ( ! ${?LIBRARY_COMBO} ) then
  setenv LIBRARY_COMBO "gnu-fd-nil"
endif

if ( ! ${?GNUSTEP_MAKEFILES} ) then
  setenv GNUSTEP_MAKEFILES "${GNUSTEP_SYSTEM_ROOT}/Library/Makefiles"
endif

if ( ! ${?GNUSTEP_USER_DIR} ) then
  setenv GNUSTEP_USER_DIR "GNUstep"
endif

#
# Set GNUSTEP_USER_ROOT which is the variable used in practice
#
switch ("${GNUSTEP_USER_DIR}")
 case /*: # An absolute path
   setenv GNUSTEP_USER_ROOT "${GNUSTEP_USER_DIR}"
   breaksw
 default: # Something else
   setenv GNUSTEP_USER_ROOT "${GNUSTEP_HOME}/${GNUSTEP_USER_DIR}"
   breaksw
endsw

# No longer needed
unset GNUSTEP_HOME

if ( "" == "" ) then
  setenv GNUSTEP_HOST "powerpc-unknown-linux-gnu"
  setenv GNUSTEP_HOST_CPU "powerpc"
  setenv GNUSTEP_HOST_VENDOR "unknown"
  setenv GNUSTEP_HOST_OS "linux-gnu"
endif

#
# Determine the host information
#
if ( ! ${?GNUSTEP_HOST} ) then
  pushd /tmp > /dev/null
  setenv GNUSTEP_HOST `${GNUSTEP_MAKEFILES}/config.guess`
  setenv GNUSTEP_HOST `${GNUSTEP_MAKEFILES}/config.sub ${GNUSTEP_HOST}`
  popd > /dev/null
endif

if ( ! ${?GNUSTEP_HOST_CPU} ) then
  setenv GNUSTEP_HOST_CPU `${GNUSTEP_MAKEFILES}/cpu.sh ${GNUSTEP_HOST}`
  setenv GNUSTEP_HOST_CPU `${GNUSTEP_MAKEFILES}/clean_cpu.sh ${GNUSTEP_HOST_CPU}`
endif

if ( ! ${?GNUSTEP_HOST_VENDOR} ) then
  setenv GNUSTEP_HOST_VENDOR `${GNUSTEP_MAKEFILES}/vendor.sh ${GNUSTEP_HOST}`
  setenv GNUSTEP_HOST_VENDOR `${GNUSTEP_MAKEFILES}/clean_vendor.sh ${GNUSTEP_HOST_VENDOR}`
endif

if ( ! ${?GNUSTEP_HOST_OS} ) then
  setenv GNUSTEP_HOST_OS `${GNUSTEP_MAKEFILES}/os.sh ${GNUSTEP_HOST}`
  setenv GNUSTEP_HOST_OS `${GNUSTEP_MAKEFILES}/clean_os.sh ${GNUSTEP_HOST_OS}`
endif

#
# Add the GNUstep tools directories to the path
#
if ( ! ${?GNUSTEP_PATHLIST} ) then
  setenv GNUSTEP_PATHLIST \
         "${GNUSTEP_USER_ROOT}:${GNUSTEP_LOCAL_ROOT}:${GNUSTEP_NETWORK_ROOT}:${GNUSTEP_SYSTEM_ROOT}"
endif

set temp_path = ""
foreach dir ( `/bin/sh -c 'IFS=:; for i in ${GNUSTEP_PATHLIST}; do echo $i; done'` )
  set temp_path="${temp_path}${dir}/Tools:"
  if ( "${GNUSTEP_FLATTENED}" == "" ) then
    set temp_path="${temp_path}${dir}/Tools/${GNUSTEP_HOST_CPU}/${GNUSTEP_HOST_OS}/${LIBRARY_COMBO}:"
    set temp_path="${temp_path}${dir}/Tools/${GNUSTEP_HOST_CPU}/${GNUSTEP_HOST_OS}:"
  endif
end

if ( ! ${?PATH} ) then
  setenv PATH "${temp_path}"
else if ( { (echo "$PATH" | fgrep -v "$temp_path" >/dev/null) } ) then
  setenv PATH "${temp_path}${PATH}"
endif
unset temp_path dir

source "${GNUSTEP_MAKEFILES}/ld_lib_path.csh"

# FIXME/TODO - use GNUSTEP_PATHLIST here
set gnustep_class_path="${GNUSTEP_USER_ROOT}/Library/Libraries/Java:${GNUSTEP_LOCAL_ROOT}/Library/Libraries/Java:${GNUSTEP_NETWORK_ROOT}/Library/Libraries/Java:${GNUSTEP_SYSTEM_ROOT}/Library/Libraries/Java"

if ( ! ${?CLASSPATH} ) then
  setenv CLASSPATH "${gnustep_class_path}"
else if ( { (echo "${CLASSPATH}" | fgrep -v "${gnustep_class_path}" >/dev/null) } ) then
  setenv CLASSPATH "${CLASSPATH}:${gnustep_class_path}"
endif

unset gnustep_class_path

set gnustep_guile_path="${GNUSTEP_USER_ROOT}/Libraries/Guile:${GNUSTEP_LOCAL_ROOT}/Libraries/Guile:${GNUSTEP_NETWORK_ROOT}/Libraries/Guile:${GNUSTEP_SYSTEM_ROOT}/Libraries/Guile"

if ( $?GUILE_LOAD_PATH == 0 ) then
    setenv GUILE_LOAD_PATH "${gnustep_guile_path}"
else if ( { (echo "${GUILE_LOAD_PATH}" | fgrep -v "${gnustep_guile_path}" >/dev/null) } ) then
    setenv GUILE_LOAD_PATH "${gnustep_guile_path}:${GUILE_LOAD_PATH}"
endif

unset gnustep_guile_path

#
# Perform any user initialization
#
if ( -e "$GNUSTEP_USER_ROOT/GNUstep.csh" ) then
  source "$GNUSTEP_USER_ROOT/GNUstep.csh"
endif
