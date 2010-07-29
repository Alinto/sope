#!/bin/sh
# relative_path.sh
#
# Copyright (C) 2002 Free Software Foundation, Inc.
#
# Author: Nicola Pero <n.pero@mi.flashnet.it>
# Date: April 2001
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

# This script gets two paths as argument - and outputs a relative path
# which, when appended to the first one, gives the second one ... more
# precisely, the path of minimum length with this property.
#
# <NB: the paths must be absolute.>
#
# for example,
#
# $GNUSTEP_MAKEFILES/relative_path.sh /usr/GNUstep/Local /usr/GNUstep/System
#
# returns ../System (and not ../../GNUstep/System which is not the minimum).
#
# This is needed by `ln -s' to properly create symlinks between
# directories which are related ... but we don't know how.  We only
# need this for frameworks, which are particularly complex and
# delicate.  For example, to create the link
#
# /usr/GNUstep/System/Library/Libraries/ix86/linux-gnu/gnu-gnu-gnu/libnicola.so
#   --> ../../../../Frameworks/nicola.framework/Versions/Current/ix86/linux-gnu/gnu-gnu-gnu/libnicola.so
#
# (and where the paths are actually computed by make variables which
# might depend on variables in user makefiles outside our control, so
# it's not obvious what the relationship is between the two paths, and
# you only have the absolute paths) we do -
#
# cd /usr/GNUstep/System/Library/Libraries/ix86/linux-gnu/gnu-gnu-gnu/
# $(LN_S) `$(RELATIVE_PATH_SCRIPT) /usr/GNUstep/System/Frameworks/nicola.framework/Versions/Current/ix86/linux-gnu/gnu-gnu-gnu/libnicola.so /usr/GNUstep/System/Library/Libraries/ix86/linux-gnu/gnu-gnu-gnu/` libnicola.so
#
# which creates the link.  We need to use the minimum path because
# that is the most relocatable possible path.  I consider all this a
# trick and a hack and recommend to use libraries and bundles instead
# of frameworks, since libraries and bundles are much more portable
# and stable, anyway here we are.
#


if [ "$#" != 2 ]; then
  exit 1
fi

a="$1";
b="$2";

if [ "$a" = "" ]; then
  exit 1
fi

if [ "$b" = "" ]; then
  exit 1
fi


#
# Our first argument is a path like /xxx/yyy/zzz/ccc/ttt
# Our second argument is a path like /xxx/yyy/kkk/nnn/ppp
#

# Step zero is normalizing the paths by removing any /./ component
# inside the given paths (these components can occur for example when
# enable-flattened is used).
tmp_IFS="$IFS"
IFS=/

# Normalize a by removing any '.' path component.
normalized_a=""
for component in $a; do
  if [ -n "$component" ]; then
    if [ "$component" != "." ]; then
      normalized_a="$normalized_a/$component"
    fi
  fi
done
a="$normalized_a"

# Normalize b by removing any '.' path component.
normalized_b=""
for component in $b; do
  if [ -n "$component" ]; then
    if [ "$component" != "." ]; then
      normalized_b="$normalized_b/$component"
    fi
  fi
done
b="$normalized_b"

IFS="$tmp_IFS"



# Step one: we first want to remove the common root -- we want to get
# into having /zzz/ccc/tt and /kkk/nnn/ppp.

# We first try to match as much as possible between the first and the second
# So we loop on the fields in the second.  The common root must not contain
# empty path components (/./) for this to work, but we have already filtered
# those out at step zero.
tmp_IFS="$IFS"
IFS=/
partial_b=""
partial_match=""
for component in $b; do
  if [ -n "$component" ]; then
    partial_b="$partial_b/$component"
    case "$a" in
      "$partial_b"*) partial_match="$partial_b";;
      *) break;;
    esac
  fi
done
IFS="$tmp_IFS"

if [ "$partial_match" != "" ]; then
  # Now partial_match is the substring which matches (/xxx/yyy/) in the
  # example.  Remove it from both a and b.
  a=`echo $a | sed -e "s#$partial_match##"`
  b=`echo $b | sed -e "s#$partial_match##"`
fi

# Ok - now ready to build the result
result=""

# First add as many ../ as there are components in a
tmp_IFS="$IFS"
IFS=/
for component in $a; do
  if [ -n "$component" -a "$component" != "." ]; then
    if [ -z "$result" ]; then
      result=".."
    else
      result="$result/.."
    fi
  fi
done
IFS="$tmp_IFS"

# Then, append b
if [ -n "$result" ]; then
  result="$result$b"
else
  result="$b"
fi

echo "$result"
