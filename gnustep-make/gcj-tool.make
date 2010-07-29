#
#   gcj-tool.make
#
#   Makefile rules to build GNUstep-based command line ctools.
#
#   Copyright (C) 2002, 2006 Free Software Foundation, Inc.
#
#   Author:  Nicola Pero <nicola@brainstorm.co.uk>
#   Author:  Helge Hess  <helge.hess@opengroupware.org>
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

ifeq ($(GNUSTEP_INSTANCE),)
include $(GNUSTEP_MAKEFILES)/Master/gcj-tool.make
else

ifeq ($(GNUSTEP_TYPE),aotjavatool)
include $(GNUSTEP_MAKEFILES)/Instance/gcj-tool.make
endif

endif
