# 
# GNUmakefile
#
# Copyright (C) 2004-2007 SKYRIX Software AG
#
# Author: Helge Hess (helge.hess@skyrix.com)
#
# This file is part of the PostgreSQL Adaptor Library
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

BUNDLE_NAME = PostgreSQL

PostgreSQL_PCH_FILE = common.h

PostgreSQL_OBJC_FILES = \
	PGConnection.m			\
	PGResultSet.m			\
	PostgreSQL72Expression.m	\
	PostgreSQL72Adaptor.m		\
	PostgreSQL72Context.m		\
	PostgreSQL72Channel.m		\
	PostgreSQL72Channel+Model.m	\
	PostgreSQL72Exception.m		\
	NSString+PostgreSQL72.m		\
	EOAttribute+PostgreSQL72.m	\
	NSString+PGVal.m		\
	NSData+PGVal.m			\
	NSCalendarDate+PGVal.m		\
	NSNumber+PGVal.m		\
	EOKeyGlobalID+PGVal.m		\
	NSNull+PGVal.m			\
	NSNumber+ExprValue.m		\
	PostgreSQL72DataTypeMappingException.m

PostgreSQL_PRINCIPAL_CLASS = PostgreSQL72Adaptor

BUNDLE_INSTALL     = PostgreSQL

# Use .gdladaptor as the bundle extension
BUNDLE_EXTENSION = .gdladaptor

PostgreSQL_RESOURCE_FILES += Version

# tool

TOOL_NAME = gdltest

gdltest_OBJC_FILES = gdltest.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
#include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
