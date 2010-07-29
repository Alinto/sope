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

FHS_BIN_DIR=$(FHS_INSTALL_ROOT)/bin/

fhs-bin-dirs ::
	$(MKDIRS) $(FHS_BIN_DIR)

NONFHS_BINDIR="$(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)"

move-tools-to-fhs :: fhs-bin-dirs
	@echo "moving tools from $(NONFHS_BINDIR) to $(FHS_BIN_DIR) .."
	for i in $(TOOL_NAME); do \
	  mv "$(NONFHS_BINDIR)/$${i}" $(FHS_BIN_DIR); \
	done

move-to-fhs :: move-tools-to-fhs

after-install :: move-to-fhs

endif
