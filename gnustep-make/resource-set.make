#
#   resource-set.make
#
#   Makefile rules to install resource files.
#
#   Copyright (C) 2002 Free Software Foundation, Inc.
#
#   Author:  Nicola Pero <nicola@brainstorm.co.uk>
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
include $(GNUSTEP_MAKEFILES)/Master/resource-set.make
else

ifeq ($(GNUSTEP_TYPE),resource_set)
include $(GNUSTEP_MAKEFILES)/Instance/resource-set.make
endif

endif
