# $Id$
# 
#  GNUmakefile.gnustep
#
#  Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
#  All rights reserved.
#
#  Author: Ovidiu Predescu <ovidiu@net-community.com>
#  Date: October 1997
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

-include gsfix.make

ifeq ($(GNUSTEP_MAKEFILES),)

$(warning ERROR: Your $(GNUSTEP_MAKEFILES) environment variable is empty !)
$(error Please try again after running ". $(GNUSTEP_MAKEFILES)/GNUstep.sh")

else

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

SUBPROJECTS = Foundation Resources examples

include $(GNUSTEP_MAKEFILES)/aggregate.make

after-distclean::
	rm -f config.cache config.log config.status config.h config.mak

after-install ::
	$(INSTALL_DATA) Foundation/libFoundation.make $(INSTALL_ROOT_DIR)$(GNUSTEP_MAKEFILES)/Additional/

endif
