#!/bin/sh
# transform_paths.sh
#
# Copyright (C) 1997 Free Software Foundation, Inc.
#
# Author: Ovidiu Predescu <ovidiu@net-community.com>
# Date: October 1997
# Rewritten: Nicola Pero <n.pero@mi.flashnet.it>
# Date: March 2001
#
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

# Takes a list of paths possibly containing relative paths and outputs a
# list containing only absolute paths based upon the current directory.

if [ -z "$*" ]; then
  exit 0
fi

curdir="`pwd`"

for dir in $@; do
  if [ -d "$curdir/$dir" ]; then
    echo "$curdir/$dir"
  else
    echo "$dir"
  fi
done
