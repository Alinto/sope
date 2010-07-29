#!/bin/sh
# move_obsolete_paths.sh
#
# Copyright (C) 2003 Free Software Foundation, Inc.
#
# Author: Adam Fedor <fedor@doc.com>
# Date: April 2003
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

# Move old paths from previous filesystem heirarchy to new location

if [ -z "$*" ]; then
  exit 0
fi

for dir in $@; do
  # 
  # Move from root to root/Library
  #
  subpath=Makefiles
  if [ -d $dir/$subpath ]; then
    echo -n "  $dir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $dir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=Libraries
  if [ -d $dir/$subpath ]; then
    echo -n "  $dir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $dir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=Headers
  if [ -d $dir/$subpath ]; then
    echo -n "  $dir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $dir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=Documentation
  if [ -d $dir/$subpath ]; then
    echo -n "  $dir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $dir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=Services
  if [ -d $dir/$subpath ]; then
    echo -n "  $dir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $dir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  # 
  # Move from root/Library/Libraries/Resources to root/Library
  #
  resourcedir=$dir/Libraries/Resources
  subpath=DocTemplates
  if [ -d $resourcedir/$subpath ]; then
    echo -n "  $resourcedir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $resourcedir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=DTDs
  if [ -d $resourcedir/$subpath ]; then
    echo -n "  $resourcedir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $resourcedir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=Images
  if [ -d $resourcedir/$subpath ]; then
    echo -n "  $resourcedir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $resourcedir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  subpath=KeyBindings
  if [ -d $resourcedir/$subpath ]; then
    echo -n "  $resourcedir/$subpath: "
    if [ -d $dir/Library/$subpath ]; then
      echo Cannot move. Already exists in new location
    else
      mv $resourcedir/$subpath $dir/Library/$subpath
      echo done
    fi
  fi

  # 
  # Remove these - will get reinstalled with gnustep-base
  #
  subpath=English.lproj
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi
  subpath=French.lproj
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi
  subpath=German.lproj
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi
  subpath=Italian.lproj
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi
  subpath=Languages
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi
  subpath=NSCharacterSets
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi
  subpath=NSTimeZones
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi

  # 
  # Remove these - will get reinstalled with gnustep-gui
  #
  subpath=PrinterTypes
  if [ -d $resourcedir/$subpath ]; then
    rm -rf $resourcedir/$subpath
    echo Removed $resourcedir/$subpath
  fi

  # 
  # Remove these - obsolete
  #
  #if [ -d $dir/Developer ]; then
  #  rm -rf $dir/Developer
  #  echo Removed $dir/Developer
  #fi

done
