#! /bin/sh
#
# setlocaltz.sh
#
# Determine local timezone, ask user for input, save timzone
# in GNUstep timezone file (or defaults database)
#
# Copyright (C) 1999 Free Software Foundation, Inc.
#
# Author: Scott Christley <scottc@net-community.com>
#
# Date: February 1999
# 
# This file is part of the GNUstep Makefile Package.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# You should have received a copy of the GNU General Public
# License along with this library; see the file COPYING.LIB.
# If not, write to the Free Software Foundation,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

echo " "
echo "Enter the name of your timezone file"
echo "press ^D on its own line when you are done"
TZNAME=`cat`
echo " "

GNUSTEP_TIMEZONE=$GNUSTEP_SYSTEM_ROOT/Library/Libraries/Resources/gnustep-base/NSTimeZones
if [ -f $GNUSTEP_TIMEZONE/zones/$TZNAME ]; then
    echo Setting timezone to $TZNAME
    defaults write NSGlobalDomain "Local Time Zone" $TZNAME
    echo defaults database says local time zone is:
    defaults read NSGlobalDomain "Local Time Zone"
else
    echo ERROR: Cannot find timezone file: $TZNAME
    echo in $GNUSTEP_TIMEZONE/zones
    exit 1
fi
