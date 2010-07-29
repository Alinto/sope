#
#   Shared/headers.make
#
#   Makefile fragment with rules to install header files
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

#
# input variables:
#
#  TODO: document
#

#
# public targets:
# 
#  shared-instance-pch-all
#  shared-instance-pch-clean
#

ifeq ($(PRECOMPILED_HEADERS),yes)

ifneq ($($(GNUSTEP_INSTANCE)_PCH_FILE),)

# has PCH support and PCH file

# we need to use notdir() because sometimes subprojects refer to a header
# in the directory above (eg: MySubproject_PCH_FILE=../common.h)
# BUT: if I add 'notdir()' the .h=>.gch in rules.make doesn't work anymore?
$(GNUSTEP_INSTANCE)_GCH_FILE=\
  $(patsubst %.h,%$(GCH_SUFFIX),$($(GNUSTEP_INSTANCE)_PCH_FILE))

ifneq ($($(GNUSTEP_INSTANCE)_PCH_AUTOINCLUDE),no)
PCH_INCLUDE_FLAG=\
  -include $(DERIVED_SOURCES_DIR)/$(notdir $($(GNUSTEP_INSTANCE)_PCH_FILE))
endif

shared-instance-pch-all: \
	$(DERIVED_SOURCES_DIR)/$($(GNUSTEP_INSTANCE)_GCH_FILE)

shared-instance-pch-clean:
	$(RM) $(DERIVED_SOURCES_DIR)/$($(GNUSTEP_INSTANCE)_GCH_FILE)

else # no PCH file defined

shared-instance-pch-all: #@(echo "No PCH file: $(GNUSTEP_INSTANCE)_PCH_FILE" )

shared-instance-pch-clean:

endif

else # no PCH in compiler

shared-instance-pch-all: #@(echo "No PCH support in compiler." )

shared-instance-pch-clean:

endif # no PCH in compiler
