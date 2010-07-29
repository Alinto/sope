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

-include ../gsfix.make

ifeq ($(GNUSTEP_MAKEFILES),)

$(warning ERROR: Your $(GNUSTEP_MAKEFILES) environment variable is empty !)
$(error Please try again after running ". $(GNUSTEP_MAKEFILES)/GNUstep.sh")

else

# ZNeK: hardcoded this due to removal of support for other runtimes
OBJC_RUNTIME=GNU

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make
-include ../Foundation/libFoundation.make

ifeq ($(gc), yes)
ifeq ($(LIBFOUNDATION_WITH_GC), yes)
GNUSTEP_OBJ_DIR = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)-gc
GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)-gc
else # $(LIBFOUNDATION_WITH_GC) == no
GNUSTEP_OBJ_DIR = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
endif
else # $(gc) == no
GNUSTEP_OBJ_DIR = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
endif

ADDITIONAL_LIB_DIRS = \
	-L../Foundation/$(GNUSTEP_OBJ_DIR) \

ifeq ($(findstring _64, $(GNUSTEP_TARGET_CPU)), _64)
SYSTEM_LIB_DIR += \
	-L$(FHS_INSTALL_ROOT)/lib64	\
	-L/usr/local/lib64		\
	-L/usr/lib64
else
SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib
endif

ADDITIONAL_INCLUDE_DIRS = \
	-I..	\
	-I../Foundation/$(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)/$(OBJC_RUNTIME)

TOOL_NAME = Defaults

ifeq ($(examples),yes)
TOOL_NAME += fmls fmrm printenv chkdict
endif

Defaults_OBJC_FILES = Defaults.m
fmls_OBJC_FILES     = fmls.m
fmrm_OBJC_FILES     = fmrm.m
printenv_OBJC_FILES = printenv.m
chkdict_OBJC_FILES  = chkdict.m

ADDITIONAL_TOOL_LIBS += -lFoundation

include $(GNUSTEP_MAKEFILES)/tool.make

include fhs.make

endif
