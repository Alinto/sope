#  fhs.make
#
#  Copyright (C) 2004 Helge Hess.
#  All rights reserved.
#
#  Author: Helge Hess <helge.hess@opengroupware.org>
#  Date: Ausgust 2004
#
#  This file is part of libFoundation.
#
#  Permission to use, copy, modify, and distribute this software and its
#  documentation for any purpose and without fee is hereby granted, provided
#  that the above copyright notice appear in all copies and that both that
#  copyright notice and this permission notice appear in supporting
#  documentation.
#
#  We disclaim all warranties with regard to this software, including all
#  implied warranties of merchantability and fitness, in no event shall
#  we be liable for any special, indirect or consequential damages or any
#  damages whatsoever resulting from loss of use, data or profits, whether in
#  an action of contract, negligence or other tortious action, arising out of
#  or in connection with the use or performance of this software.
#

# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

FHS_INCLUDE_DIR=$(FHS_INSTALL_ROOT)/include/

ifeq ($(findstring _64, $(GNUSTEP_TARGET_CPU)), _64)
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib64/
else
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib/
endif

fhs-header-dirs ::
	$(MKDIRS) $(FHS_INCLUDE_DIR)
	$(MKDIRS) $(FHS_INCLUDE_DIR)/Foundation
	$(MKDIRS) $(FHS_INCLUDE_DIR)/Foundation/exceptions
	$(MKDIRS) $(FHS_INCLUDE_DIR)/extensions

move-headers-to-fhs :: fhs-header-dirs
	@echo "moving headers to $(FHS_INCLUDE_DIR) .."
	mv $(DIR_FD)/Foundation/*.h $(FHS_INCLUDE_DIR)/Foundation/
	mv $(DIR_FD)/Foundation/exceptions/*.h \
	   $(FHS_INCLUDE_DIR)/Foundation/exceptions/
	mv $(DIR_FD)/extensions/*.h $(FHS_INCLUDE_DIR)/extensions/
	mv $(DIR_FD)/$(CTO)/*.h	$(FHS_INCLUDE_DIR)

NONFHS_LIBDIR="$(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR)/"
NONFHS_LIBNAME="$(LIBRARY_NAME)$(LIBRARY_NAME_SUFFIX)$(SHARED_LIBEXT)"

move-libs-to-fhs :: 
	@echo "moving libs to $(FHS_LIB_DIR) .."
	mv $(NONFHS_LIBDIR)/$(NONFHS_LIBNAME)* $(FHS_LIB_DIR)/

move-to-fhs :: move-headers-to-fhs move-libs-to-fhs

after-install :: move-to-fhs

endif
