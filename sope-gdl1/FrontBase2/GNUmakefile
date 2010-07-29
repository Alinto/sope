# 
# GNUmakefile
#
# Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
#
# Author: Helge Hess (helge.hess@mdlink.de)
#
# This file is part of the FrontBase Adaptor Library
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

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

CAN_COMPILE_FB = \
	$(shell ./cancompile.sh $(GNUSTEP_TARGET_CPU) $(GNUSTEP_TARGET_OS))

ifeq ($(CAN_COMPILE_FB),yes)

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)

BUNDLE_NAME = FrontBase2

FrontBase2_OBJC_FILES = \
	FBSQLExpression.m	\
	FBException.m		\
	FrontBase2Adaptor.m	\
	FBAdaptor+Types.m	\
	FBContext.m		\
	FBChannel.m		\
	EOAttribute+FB.m	\
	NSString+FB.m		\
	FBValues.m		\
	FBChannel+Model.m	\
	FBBlobHandle.m		\

FrontBase2_PRINCIPAL_CLASS = FrontBase2Adaptor
FrontBase2_RESOURCE_FILES  = Info.plist Version

BUNDLE_INSTALL     = FrontBase2
BUNDLE_INSTALL_DIR = $(GNUSTEP_SYSTEM_ROOT)/Libraries/Adaptors

# Use .gdladaptor as the bundle extension
BUNDLE_EXTENSION = .gdladaptor

# tool stuff

TOOL_NAME = fbtest

fbtest_OBJC_FILES = fbtest.m
#fbtest_OBJC_FILES += $(FrontBase2_OBJC_FILES)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
#include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble

else # cannot compile FB

cannotcompile :
	echo "cannot compile FrontBase 2.x adaptor for OS $(GNUSTEP_TARGET_OS) CPU $(GNUSTEP_TARGET_CPU)"

all :: cannotcompile

clean ::

install :: cannotcompile

endif 
