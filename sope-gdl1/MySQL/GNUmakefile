# 
# GNUmakefile
#
# Copyright (C) 2005 Helge Hess
#
# Author: Helge Hess (helge.hess@opengroupware.org)
#
# This file is part of the MySQL4 Adaptor Library
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; see the file COPYING.LIB.
# If not, write to the Free Software Foundation,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

BUNDLE_NAME = MySQL

MySQL_PCH_FILE = common.h

MySQL_OBJC_FILES = \
	MySQL4Expression.m		\
	MySQL4Adaptor.m			\
	MySQL4Context.m			\
	MySQL4Channel.m			\
	MySQL4Channel+Model.m		\
	MySQL4Exception.m		\
	MySQL4Values.m			\
	NSString+MySQL4.m		\
	EOAttribute+MySQL4.m		\
	NSString+MySQL4Val.m		\
	NSData+MySQL4Val.m		\
	NSCalendarDate+MySQL4Val.m	\
	NSNumber+MySQL4Val.m		\

MySQL_PRINCIPAL_CLASS = MySQL4Adaptor

BUNDLE_INSTALL = MySQL

# Use .gdladaptor as the bundle extension
BUNDLE_EXTENSION = .gdladaptor

MySQL_RESOURCE_FILES += Version

# tool

TOOL_NAME = gdltest

gdltest_OBJC_FILES = gdltest.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
ifeq ($(test),yes)
include $(GNUSTEP_MAKEFILES)/tool.make
endif
-include GNUmakefile.postamble
