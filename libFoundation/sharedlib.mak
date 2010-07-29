#  sharedlib.mak
#
#  Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
#  All rights reserved.
#
#  Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
#  Date: March 1997
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


HAVE_SHARED_LIBS	= no
SHARED_LIB_DIR		= $(libdir)
SHARED_OBJDIR		= $(OBJDIR)

#
# OpenStep 4.x
#
ifeq ($(TARGET_OS), nextstep4)
HAVE_SHARED_LIBS	= yes
SHARED_LIB_DIR		= $(libdir)
SHARED_OBJDIR		= shared_obj

ifeq ($(WITH_GC), yes)
GC_LIB	= -lgc
endif

SHARED_LIB_LINK_CMD	= \
	libtool -dynamic -read_only_relocs suppress -o $@ \
		-framework System -L$(SHARED_LIB_DIR) -lobjc -lgcc $(GC_LIB) $^

INSTALL_SHARED_LIB_CMD	= \
	cp $(LIB_FOUNDATION_NAME) \
		$(SHARED_LIB_DIR)/$(LIB_FOUNDATION_NAME)

ADDITIONAL_CC_FLAGS	+= -dynamic
shared_libext	= .a
endif


#
# Linux ELF
#
ifeq ($(findstring linux, $(TARGET_OS)), linux)
HAVE_SHARED_LIBS	= yes
SHARED_LIB_DIR		= $(libdir)
SHARED_OBJDIR		= shared_obj
SHARED_LIB_LINK_CMD	= \
	$(CC) -shared -o $@ -Wl,-soname=$(LIB_FOUNDATION_NAME).$(VERSION) $^

INSTALL_SHARED_LIB_CMD	= \
	cp $(LIB_FOUNDATION_NAME) $(SHARED_LIB_DIR)/$(LIB_FOUNDATION_NAME).$(VERSION); \
	(cd $(SHARED_LIB_DIR); \
	 rm $(LIB_FOUNDATION_NAME); \
	 ln -sf $(LIB_FOUNDATION_NAME).$(VERSION) $(LIB_FOUNDATION_NAME))

ADDITIONAL_CC_FLAGS	+= -fPIC
shared_libext	= .so
endif


#
# Solaris
#
ifeq ($(findstring solaris, $(TARGET_OS)), solaris)
HAVE_SHARED_LIBS	= yes
SHARED_LIB_DIR		= $(libdir)
SHARED_OBJDIR		= shared_obj
SHARED_LIB_LINK_CMD	= \
	$(CC) -G -o $@ $^

INSTALL_SHARED_LIB_CMD	= \
	cp $(LIB_FOUNDATION_NAME) $(SHARED_LIB_DIR)/$(LIB_FOUNDATION_NAME).$(VERSION); \
	(cd $(SHARED_LIB_DIR); \
	 rm $(LIB_FOUNDATION_NAME); \
	 ln -sf $(LIB_FOUNDATION_NAME).$(VERSION) $(LIB_FOUNDATION_NAME))

ADDITIONAL_CC_FLAGS	+= -fpic -fPIC
shared_libext	= .so
endif
