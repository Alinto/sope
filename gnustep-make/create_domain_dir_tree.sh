#!/bin/sh
# create_domain_dir_tree.sh
#
# Copyright (C) 2002 Free Software Foundation, Inc.
#
# Author: Nicola Pero <n.pero@mi.flashnet.it>
# Date: October 2002
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

# Take a single argument - a directory name -, and create the GNUstep
# domain directory structure inside the directory.

# It is automatically called with argument ${GNUSTEP_SYSTEM_ROOT} when
# gnustep-make is installed; you can call it with argument
# ${GNUSTEP_LOCAL_ROOT} or ${GNUSTEP_NETWORK_ROOT} (or your own
# GNUstep user dir) if you need to create manually a GNUstep domain
# directory tree in there.

if [ -z "$*" ]; then
  echo "No arguments specified" >&2
  exit 0
fi

# The original code
# mydir=`dirname "$0"`

# But it seems that on OpenStep, dirname is not available, so we use
# the following trick.  The sed expression replaces /[^/]*$ (which
# means '/' followed by a sequence of zero or more non-'/' characters,
# followed by end-of-line) with nothing (that is, it deletes it), and
# what remains is the dirname.
mydir=`echo "$0" | sed -e "s#/[^/]*\\\$##"`

basepath="$1"

${mydir}/mkinstalldirs  "$basepath" \
		"$basepath"/Applications \
		"$basepath"/Tools/${GNUSTEP_TARGET_LDIR} \
		"$basepath"/Tools/Resources \
		"$basepath"/Tools/Java \
		"$basepath"/Library/ApplicationSupport \
		"$basepath"/Library/Bundles \
		"$basepath"/Library/ColorPickers \
		"$basepath"/Library/Colors \
		"$basepath"/Library/DocTemplates \
		"$basepath"/Library/Documentation/Developer \
		"$basepath"/Library/Documentation/User \
		"$basepath"/Library/Documentation/info \
		"$basepath"/Library/Documentation/man \
		"$basepath"/Library/Fonts \
		"$basepath"/Library/Frameworks \
		"$basepath"/Library/Headers/${MAYBE_LIBRARY_COMBO}/${GNUSTEP_TARGET_DIR} \
		"$basepath"/Library/Images \
		"$basepath"/Library/KeyBindings \
		"$basepath"/Library/Libraries/${GNUSTEP_TARGET_LDIR} \
		"$basepath"/Library/Libraries/Resources \
		"$basepath"/Library/Libraries/Java \
		"$basepath"/Library/PostScript \
		"$basepath"/Library/Services \
		"$basepath"/Library/Sounds

