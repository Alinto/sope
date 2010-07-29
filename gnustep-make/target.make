#
#   target.make
#
#   Determine target specific settings
#
#   Copyright (C) 1997 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
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

# This file should not contain any conditional based on the value of
# the 'shared' variable, because we have not set it up yet when this
# file is processed!

#
# Host and target specific settings
#
ifeq ($(findstring solaris, $(GNUSTEP_TARGET_OS)), solaris)
X_INCLUDES := $(X_INCLUDES)/X11
endif

#
# Target specific libraries
#
TARGET_SYSTEM_LIBS = $(CONFIG_SYSTEM_LIBS) -lm
ifneq ("$(objc_threaded)","")
  INTERNAL_CFLAGS = -D_REENTRANT
  INTERNAL_OBJCFLAGS = -D_REENTRANT
  AUXILIARY_OBJC_LIBS += $(objc_threaded)
ifeq ($(shared), no)
  TARGET_SYSTEM_LIBS += $(objc_threaded)
endif
endif

ifeq ($(findstring mingw32, $(GNUSTEP_TARGET_OS)), mingw32)
  TARGET_SYSTEM_LIBS = $(CONFIG_SYSTEM_LIBS) \
	-lws2_32 -ladvapi32 -lcomctl32 -luser32 -lcomdlg32 \
	-lmpr -lnetapi32 -lm -I. # the -I is a dummy to avoid -lm^M
endif
ifeq ($(findstring cygwin, $(GNUSTEP_TARGET_OS)), cygwin)
  TARGET_SYSTEM_LIBS = $(CONFIG_SYSTEM_LIBS) -lm -I. 
endif
ifeq ($(findstring solaris, $(GNUSTEP_TARGET_OS)), solaris)
  TARGET_SYSTEM_LIBS = $(CONFIG_SYSTEM_LIBS) -lsocket -lnsl -lm
endif
ifeq ($(findstring sysv4.2, $(GNUSTEP_TARGET_OS)), sysv4.2)
  TARGET_SYSTEM_LIBS = $(CONFIG_SYSTEM_LIBS) -lsocket -lnsl -lm
endif

#
# Specific settings for building shared libraries, static libraries,
# and bundles on various systems
#

#
# For each target, a few target-specific variables need to be set.
#
# The first one is SHARED_LIB_LINK_CMD - which should be set to the
# command(s) to use to link a shared library on that platform.  Please
# note that the variables (stuff like $(CC)) in it are not expanded
# until SHARED_LIB_LINK_CMD is actually used (STATIC_LIB_LINK_CMD is
# the equivalent variable, used for static libraries).
#
# SHARED_LIB_LINK_CMD will be used to link standard shared libraries,
# and frameworks.  It should use the following variables (which are set
# by library.make or framework.make before executing
# SHARED_LIB_LINK_CMD) to refer to what it needs to link (please note
# that STATIC_LIB_LINK_CMD will also use these variables with similar
# meanings; but not all of them, as noted):
#
#  LIB_LINK_OBJ_DIR: where the newly created library should be. 
#    Usually GNUSTEP_OBJ_DIR for libraries, and FRAMEWORK_LIBRARY_DIR_NAME 
#    for frameworks.
#  LIB_LINK_VERSION_FILE: the final file to create, having full
#     version information: typically `libgnustep-base.so.1.5.3' for shared
#     libraries, and `libgnustep-base.a' for static libraries.  For DLL
#     libraries, this is the import library libgnustep-base.dll.a.  The
#     reason we use the import library is because that is the code which
#     needs to be installed in the library path.  So by setting
#     LIB_LINK_VERSION_FILE to the import library, the standard code to
#     install it in the library path will work for Windows.  The DLL
#     library instead needs to be installed in the PATH, so we have separate
#     code for that one.
#  LIB_LINK_SONAME_FILE: this is only used for shared libraries; it 
#    should be passed in the -Wl,-soname argument of most linkers when 
#    building the LIB_LINK_VERSION_FILE. Typically `libgnustep-base.so.1' 
#    (but might also be `libgnustep-base.so.1.0' if INTERFACE_VERSION
#    has been manually changed when using library.make).  On many
#    platforms, it's appropriate/standard to also create this file as
#    a symlink to LIB_LINK_VERSION_FILE.  If LIB_LINK_VERSION_FILE is
#    the same as LIB_LINK_SONAME_FILE, then the symlink should not be
#    created.
#  LIB_LINK_FILE: this is only used for shared libraries; it should
#    be created as a symlink to LIB_LINK_VERSION_FILE (or to 
#    LIB_LINK_SONAME_FILE if it's created on that platform).
#    Typically `libgnustep-base.so'.
#  LIB_LINK_INSTALL_NAME: on some platforms, when a shared library is
#    linked, a default install name of the library is hardcoded into
#    the library.  This is that name.
#  LIB_LINK_DLL_FILE: on Windows, this is the DLL that gets created
#    and installed in the Tools/ directory (eg, gnustep-base.dll).
#    Please note that while this is the main file you need to use the
#    library at runtime, on Windows we treat this as a side-effect of
#    the compilation; the compilation target for make is
#    LIB_LINK_VERSION_FILE, which is the import library.

# AFTER_INSTALL_SHARED_LIB_CMD provides commands to be executed after
# installation (at least for libraries, not for frameworks at the
# moment), and is supposed to setup symlinks properly in the
# installation directory.  It uses the same variables, except for
# LIB_LINK_INSTALL_DIR which is the full final path to where the
# library (and symlinks) is going to be installed.
#
# AFTER_INSTALL_STATIC_LIB_CMD is similar.
#

# For frameworks on unusual platforms, you might also need to set
# EXTRACT_CLASS_NAMES_COMMAND.  This should be a command which is
# evaluated on $(object_file) and returns a list of classes
# implemented in the object_file.  Our default command is the
# following (you can override it with another one in your target's
# section if you need), which runs 'nm' on the object file, and
# retrieve all symbols of the form __objc_class_name_NSObject which
# are not 'U' (undefined) ... an __objc_class_name_NSObject is defined
# in the module implementing the class, and referenced by all other
# modules needing to use the class.  So if we have an
# __objc_class_name_XXX which is not 'U' (which would be a reference
# to a class implemented elsewhere), it must be a class implemented in
# this module.
#
# The 'sed' command parses a set of lines, and extracts lines starting
# with __objc_class_name_XXXX Y, where XXXX is a string of characters
# from A-Za-z_. and Y is not 'U'.  It then replaces the whole line
# with XXXX, and prints the result. '-n' disables automatic printing
# for portability, so we are sure we only print what we want on all
# platforms.
EXTRACT_CLASS_NAMES_COMMAND = nm -Pg $$object_file | sed -n -e '/^__objc_class_name_[A-Za-z_.]* [^U]/ {s/^__objc_class_name_\([A-Za-z_.]*\) [^U].*/\1/p;}'

#
# This is the generic version - if the target is not in the following list,
# this setup will be used.  It the target does not override variables here
# with its own version, these generic definitions will be used.
#
HAVE_SHARED_LIBS = no
STATIC_LIB_LINK_CMD = \
	$(AR) $(ARFLAGS) $(AROUT)$(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^;\
	$(RANLIB) $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE)
AFTER_INSTALL_STATIC_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	$(RANLIB) $(LIB_LINK_VERSION_FILE))
SHARED_LIB_LINK_CMD =
SHARED_CFLAGS =
SHARED_LIBEXT =
AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	 $(RM_LN_S) $(LIB_LINK_FILE); \
	 $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
AFTER_INSTALL_SHARED_LIB_CHOWN = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	chown $(CHOWN_TO) $(LIB_LINK_FILE))
HAVE_BUNDLES = no
BUNDLE_LINK_CMD = $(BUNDLE_LD) $(BUNDLE_LDFLAGS) $(ALL_LDFLAGS) \
                -o $(LDOUT)$(BUNDLE_FILE) $(OBJ_FILES_TO_LINK) \
		$(ALL_BUNDLE_LIBS)

####################################################
#
# Start of system specific settings
#
####################################################

####################################################
#
# MacOSX-Server 1.0
#
ifeq ($(findstring rhapsody5, $(GNUSTEP_TARGET_OS)), rhapsody5)
ifeq ($(OBJC_RUNTIME_LIB), apple)
HAVE_BUNDLES     = yes
endif

HAVE_SHARED_LIBS = yes
SHARED_LIBEXT    = .dylib

ifeq ($(FOUNDATION_LIB), apple)
  # Use the NeXT compiler
  CC = cc
  OBJC_COMPILER = NeXT
  ifneq ($(arch),)
    ARCH_FLAGS = $(foreach a, $(arch), -arch $(a))
    INTERNAL_OBJCFLAGS += $(ARCH_FLAGS)
    INTERNAL_CFLAGS    += $(ARCH_FLAGS)
    INTERNAL_LDFLAGS   += $(ARCH_FLAGS)
  endif
endif

TARGET_LIB_DIR = \
    Library/Libraries/$(GNUSTEP_TARGET_LDIR)

ifneq ($(OBJC_COMPILER), NeXT)
SHARED_LIB_LINK_CMD     = \
	$(CC) $(SHARED_LD_PREFLAGS) \
		-dynamiclib $(ARCH_FLAGS) -dynamic \
		-compatibility_version 1 -current_version 1 \
		-install_name $(GNUSTEP_SYSTEM_ROOT)/$(TARGET_LIB_DIR)/$(LIB_LINK_FILE) \
		$(ALL_LDFLAGS) -o $@ \
		-framework Foundation \
		-framework System \
		$(INTERNAL_LIBRARIES_DEPEND_UPON) $(LIBRARIES_FOUNDATION_DEPEND_UPON) \
		-lobjc -lgcc $^ $(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
else # OBJC_COMPILER=NeXT
SHARED_LIB_LINK_CMD     = \
	$(CC) $(SHARED_LD_PREFLAGS) \
		-dynamiclib $(ARCH_FLAGS) -dynamic \
		-compatibility_version 1 -current_version 1 \
		-read_only_relocs warning -undefined warning \
		-install_name $(GNUSTEP_SYSTEM_ROOT)/$(TARGET_LIB_DIR)/$(LIB_LINK_FILE) \
		$(ALL_LDFLAGS) -o $@ \
		$(INTERNAL_LIBRARIES_DEPEND_UPON) $(LIBRARIES_FOUNDATION_DEPEND_UPON) \
		-framework Foundation \
		$^ $(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
endif # OBJC_COMPILER

OBJ_MERGE_CMD = \
	$(CC) -nostdlib -r -d $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

STATIC_LIB_LINK_CMD	= \
	/usr/bin/libtool $(STATIC_LD_PREFLAGS) -static $(ARCH_FLAGS) $(ALL_LDFLAGS) -o $@ $^ \
	$(STATIC_LD_POSTFLAGS)

# This doesn't work with 4.1, what about others?
#ADDITIONAL_LDFLAGS += -Wl,-read_only_relocs,suppress

AFTER_INSTALL_STATIC_LIB_CMD =

SHARED_CFLAGS   += -dynamic
SHARED_LIBEXT   = .dylib

BUNDLE_LD	=  $(CC)
BUNDLE_LDFLAGS  += -bundle -undefined suppress $(ARCH_FLAGS)
endif
#
# end MacOSX-Server 1.0
#
####################################################

####################################################
#
# MacOSX, darwin
#
ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
ifeq ($(OBJC_RUNTIME_LIB), apple)
  HAVE_BUNDLES     = yes
  # Set flags to ignore the MacOSX headers
  ifneq ($(FOUNDATION_LIB), apple)
    INTERNAL_OBJCFLAGS += -no-cpp-precomp -nostdinc -I/usr/include
  endif
endif

HAVE_SHARED_LIBS = yes
SHARED_LIBEXT    = .dylib

# The output of nm is slightly different on Darwin, it doesn't support -P
EXTRACT_CLASS_NAMES_COMMAND = nm  -g $$object_file | sed -n -e '/[^U] ___objc_class_name_/ {s/[0-9a-f]* [^U] ___objc_class_name_//p;}'

ifeq ($(FOUNDATION_LIB), apple)
  ifneq ($(arch),)
    ARCH_FLAGS = $(foreach a, $(arch), -arch $(a))
    INTERNAL_OBJCFLAGS += $(ARCH_FLAGS)
    INTERNAL_CFLAGS    += $(ARCH_FLAGS)
    INTERNAL_LDFLAGS   += $(ARCH_FLAGS)
  endif
endif

# The developer should set this explicitly
#DYLIB_COMPATIBILITY_VERSION = -compatibility_version $(VERSION)
DYLIB_CURRENT_VERSION       = -current_version $(VERSION)

# Remove empty dirs from the compiler/linker flags (ie, remove -Idir and 
# -Ldir flags where dir is empty).
REMOVE_EMPTY_DIRS = yes

ifeq ($(FOUNDATION_LIB), apple)
DYLIB_DEF_FRAMEWORKS += -framework Foundation
endif

ifeq ($(CC_BUNDLE), no)
# GNU compiler

INTERNAL_LDFLAGS += -flat_namespace -undefined warning

SHARED_LD_PREFLAGS += -Wl,-noall_load -read_only_relocs warning $(CC_LDFLAGS)
# Useful flag: -Wl,-single_module.  This flag only
# works starting with 10.3. libs w/ffcall don't link on darwin/ix86 without it.
ifeq ($(findstring darwin7, $(GNUSTEP_TARGET_OS)), darwin7)
  SHARED_LD_PREFLAGS += -single_module
endif
ifeq ($(findstring darwin8, $(GNUSTEP_TARGET_OS)), darwin8)
  SHARED_LD_PREFLAGS += -single_module
  BUNDLE_LIBS += -lSystemStubs
endif
SHARED_LIB_LINK_CMD     = \
	$(CC) \
		$(SHARED_LD_PREFLAGS) \
		$(ARCH_FLAGS) -dynamic -dynamiclib	\
		$(DYLIB_COMPATIBILITY_VERSION)		\
		$(DYLIB_CURRENT_VERSION)		\
		-install_name $(LIB_LINK_INSTALL_NAME)	\
		$(ALL_LDFLAGS) -o $@					\
		$(DYLIB_DEF_FRAMEWORKS)			\
		$^ $(INTERNAL_LIBRARIES_DEPEND_UPON) $(LIBRARIES_FOUNDATION_DEPEND_UPON) \
		$(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))

BUNDLE_LD       =  /usr/bin/ld
BUNDLE_LDFLAGS  += -bundle /usr/lib/bundle1.o

else 
# Apple Compiler

#DYLIB_EXTRA_FLAGS    = -read_only_relocs warning -undefined warning -fno-common
DYLIB_EXTRA_FLAGS    = -flat_namespace -undefined warning 
# Useful optimization flag: -Wl,-single_module.  This flag only
# works starting with 10.3.
ifeq ($(findstring darwin7, $(GNUSTEP_TARGET_OS)), darwin7)
  DYLIB_EXTRA_FLAGS    += -Wl,-single_module
endif

SHARED_LIB_LINK_CMD     = \
	$(CC) $(SHARED_LD_PREFLAGS) \
		-dynamiclib $(ARCH_FLAGS) \
		$(DYLIB_COMPATIBILITY_VERSION)		\
		$(DYLIB_CURRENT_VERSION)		\
		-install_name $(LIB_LINK_INSTALL_NAME)	\
		$(DYLIB_EXTRA_FLAGS)			\
		$(ALL_LDFLAGS) -o $@					\
		$(INTERNAL_LIBRARIES_DEPEND_UPON) $(LIBRARIES_FOUNDATION_DEPEND_UPON) \
		$^ $(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))

SHARED_CFLAGS   += -dynamic

BUNDLE_LD	=  $(CC)
BUNDLE_LDFLAGS  += -bundle -undefined error $(ARCH_FLAGS)

endif # CC_TYPE

AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
         $(RM_LN_S) $(LIB_LINK_FILE); \
         if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
           $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
         fi; \
         $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE) )

OBJ_MERGE_CMD = \
	$(CC) -nostdlib -r -d $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

STATIC_LIB_LINK_CMD	= \
	/usr/bin/libtool $(STATIC_LD_PREFLAGS) -static $(ARCH_FLAGS) $(ALL_LDFLAGS) -o $@ $^ \
	$(STATIC_LD_POSTFLAGS)

AFTER_INSTALL_STATIC_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	$(RANLIB) $(LIB_LINK_VERSION_FILE))

SHARED_CFLAGS   += -fno-common

endif
#
# end MacOSX, darwin
#
####################################################

####################################################
#
# OpenStep 4.x
#
ifeq ($(GNUSTEP_TARGET_OS), nextstep4)
ifeq ($(OBJC_RUNTIME_LIB), nx)
  HAVE_BUNDLES  = yes
  OBJC_COMPILER = NeXT
endif

HAVE_SHARED_LIBS = yes

ifeq ($(FOUNDATION_LIB), nx)
  # Use the NeXT compiler
  CC = cc
  ifneq ($(arch),)
    ARCH_FLAGS = $(foreach a, $(arch), -arch $(a))
    INTERNAL_OBJCFLAGS += $(ARCH_FLAGS)
    INTERNAL_CFLAGS += $(ARCH_FLAGS)
    INTERNAL_LDFLAGS += $(ARCH_FLAGS)
  endif
endif

TARGET_LIB_DIR = \
    Library/Libraries/$(GNUSTEP_TARGET_LDIR)

ifneq ($(OBJC_COMPILER), NeXT)
SHARED_LIB_LINK_CMD     = \
	/bin/libtool $(SHARED_LD_PREFLAGS) \
		-dynamic -read_only_relocs suppress $(ARCH_FLAGS) \
		-install_name $(GNUSTEP_SYSTEM_ROOT)/$(TARGET_LIB_DIR)/$(LIB_LINK_FILE) \
		$(ALL_LDFLAGS) -o $@ \
		-framework System \
		$(INTERNAL_LIBRARIES_DEPEND_UPON) $(LIBRARIES_FOUNDATION_DEPEND_UPON) \
		-lobjc -lgcc $^ $(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
else
SHARED_LIB_LINK_CMD     = \
        /bin/libtool $(SHARED_LD_PREFLAGS) \
		-dynamic -read_only_relocs suppress $(ARCH_FLAGS) \
		-install_name $(GNUSTEP_SYSTEM_ROOT)/$(TARGET_LIB_DIR)/$(LIB_LINK_FILE) \
		$(ALL_LDFLAGS) $@ \
		-framework System \
		$(INTERNAL_LIBRARIES_DEPEND_UPON) \
		$(LIBRARIES_FOUNDATION_DEPEND_UPON) $^ \
		$(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
endif

STATIC_LIB_LINK_CMD	= \
	/bin/libtool $(STATIC_LD_PREFLAGS) -static $(ARCH_FLAGS) $(ALL_LDFLAGS) -o $@ $^ \
	$(STATIC_LD_POSTFLAGS)

# This doesn't work with 4.1, what about others?
#ADDITIONAL_LDFLAGS += -Wl,-read_only_relocs,suppress

AFTER_INSTALL_STATIC_LIB_CMD =

SHARED_CFLAGS   += -dynamic
SHARED_LIBEXT   = .a

BUNDLE_LD	= ld
BUNDLE_LDFLAGS  += -r $(ARCH_FLAGS)
endif
#
# end OpenStep 4.x
#
####################################################

####################################################
#
# NEXTSTEP 3.x
#
ifeq ($(GNUSTEP_TARGET_OS), nextstep3)
ifeq ($(OBJC_RUNTIME_LIB), nx)
  HAVE_BUNDLES            = yes
  OBJC_COMPILER = NeXT
endif

HAVE_SHARED_LIBS        = yes

ifeq ($(FOUNDATION_LIB), nx)
  # Use the NeXT compiler
  CC = cc
  ifneq ($(arch),)
    ARCH_FLAGS = $(foreach a, $(arch), -arch $(a))
    INTERNAL_OBJCFLAGS += $(ARCH_FLAGS)
    INTERNAL_CFLAGS += $(ARCH_FLAGS)
    INTERNAL_LDFLAGS += $(ARCH_FLAGS)
  endif
endif

TARGET_LIB_DIR = \
    Library/Libraries/$(GNUSTEP_TARGET_LDIR)

ifneq ($(OBJC_COMPILER), NeXT)
SHARED_LIB_LINK_CMD     = \
        /bin/libtool $(SHARED_LD_PREFLAGS) -dynamic -read_only_relocs suppress \
		 $(ARCH_FLAGS) $(ALL_LDFLAGS) -o $@ -framework System \
		$(INTERNAL_LIBRARIES_DEPEND_UPON) -lobjc -lgcc -undefined warning $^ \
		$(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
else
SHARED_LIB_LINK_CMD     = \
        /bin/libtool $(SHARED_LD_PREFLAGS) \
		-dynamic -read_only_relocs suppress $(ARCH_FLAGS) $(ALL_LDFLAGS) -o $@ \
		-framework System \
		$(INTERNAL_LIBRARIES_DEPEND_UPON) $^ \
		$(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
endif

STATIC_LIB_LINK_CMD	= \
	/bin/libtool $(STATIC_LD_PREFLAGS) \
	-static $(ARCH_FLAGS) $(ALL_LDFLAGS) -o $@ $^ $(STATIC_LD_POSTFLAGS)

ADDITIONAL_LDFLAGS += -Wl,-read_only_relocs,suppress

AFTER_INSTALL_STATIC_LIB_CMD =

SHARED_CFLAGS   += -dynamic
SHARED_LIBEXT   = .a

BUNDLE_LD	= ld
BUNDLE_LDFLAGS  += -r $(ARCH_FLAGS)
endif
#
# end NEXTSTEP 3.x
#
####################################################

####################################################
#
# Linux ELF or GNU/Hurd
#
# The following ifeq matches both 'linux-gnu' (which is GNU/Linux ELF)
# and 'gnu0.3' (I've been told GNUSTEP_TARGET_OS is 'gnu0.3' on
# GNU/Hurd at the moment).  We want the same code in both cases.
ifeq ($(findstring gnu, $(GNUSTEP_TARGET_OS)), gnu)
HAVE_SHARED_LIBS        = yes
SHARED_LIB_LINK_CMD     = \
        $(CC) $(SHARED_LD_PREFLAGS) -shared -Wl,-soname,$(LIB_LINK_SONAME_FILE) \
           $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ \
	   $(INTERNAL_LIBRARIES_DEPEND_UPON) \
	   $(SHARED_LD_POSTFLAGS);\
	(cd $(LIB_LINK_OBJ_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CHOWN = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	chown $(CHOWN_TO) $(LIB_LINK_SONAME_FILE); \
	chown $(CHOWN_TO) $(LIB_LINK_FILE))

OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS      += -fPIC
SHARED_LIBEXT      =  .so

HAVE_BUNDLES       =  yes
BUNDLE_LD	   =  $(CC)
BUNDLE_LDFLAGS     += -shared
ADDITIONAL_LDFLAGS += -rdynamic
STATIC_LDFLAGS += -static
endif
#
# end Linux ELF
#
####################################################

####################################################
#
# FreeBSD a.out (2.2.x)
#
ifeq ($(findstring freebsdaout, $(GNUSTEP_TARGET_OS)), freebsdaout)
freebsdaout = yes

HAVE_SHARED_LIBS	= no
SHARED_LIB_LINK_CMD = \
	$(CC) -shared -Wl,-soname,$(LIB_LINK_VERSION_FILE) \
	   $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ /usr/lib/c++rt0.o;\
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
	  $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))

SHARED_CFLAGS	+= -fPIC
SHARED_LIBEXT	= .so

HAVE_BUNDLES	= yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS	+= -shared
ADDITIONAL_LDFLAGS += -rdynamic
STATIC_LDFLAGS += -static
endif
#
# end FreeBSD A.out
#
####################################################

####################################################
#
# FreeBSD ELF
#
ifeq ($(findstring freebsd, $(GNUSTEP_TARGET_OS)), freebsd)
ifneq ($(freebsdaout), yes)
HAVE_SHARED_LIBS	= yes
SHARED_LIB_LINK_CMD = \
	$(CC) -shared -Wl,-soname,$(LIB_LINK_SONAME_FILE) \
	   $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ \
	   $(INTERNAL_LIBRARIES_DEPEND_UPON) \
	   $(SHARED_LD_POSTFLAGS);\
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
	  $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE))
AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
	  $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CHOWN = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	chown $(CHOWN_TO) $(LIB_LINK_SONAME_FILE); \
	chown $(CHOWN_TO) $(LIB_LINK_FILE))
OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS	+= -fPIC
SHARED_LIBEXT	= .so

HAVE_BUNDLES	= yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS	+= -shared
ADDITIONAL_LDFLAGS += -rdynamic
STATIC_LDFLAGS += -static

##
## The -pthread flag must be passed to all compilation/link commands.
##
ifeq ($(objc_threaded), -pthread)
  INTERNAL_CFLAGS += -pthread
  INTERNAL_OBJCFLAGS += -pthread
  INTERNAL_LDFLAGS += -pthread
endif
endif
endif
#
# end FreeBSD
#
####################################################

####################################################
#
# NetBSD (ELF)
#
ifeq ($(findstring netbsd, $(GNUSTEP_TARGET_OS)), netbsd)
HAVE_SHARED_LIBS    = yes
SHARED_LD_POSTFLAGS = -Wl,-R/usr/pkg/lib -L/usr/pkg/lib
SHARED_LIB_LINK_CMD = \
	$(CC) -shared -Wl,-soname,$(LIB_LINK_VERSION_FILE) \
              $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) \
                 $^ $(INTERNAL_LIBRARIES_DEPEND_UPON) \
                 $(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
	  $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS	+= -fPIC
SHARED_LIBEXT	= .so

HAVE_BUNDLES	= yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS	+= -shared
ADDITIONAL_LDFLAGS += -rdynamic -Wl,-R/usr/pkg/lib -L/usr/pkg/lib -Wl,-R/usr/X11R6/lib -L/usr/X11R6/lib
ADDITIONAL_INCLUDE_DIRS += -I/usr/pkg/include
STATIC_LDFLAGS += -static
endif
#
# end NetBSD
#
####################################################

####################################################
#
# DragonFly
#
ifeq ($(findstring dragonfly, $(GNUSTEP_TARGET_OS)), dragonfly)
HAVE_SHARED_LIBS    = yes
SHARED_LD_POSTFLAGS = -Wl,-R/usr/pkg/lib -L/usr/pkg/lib
SHARED_LIB_LINK_CMD = \
	$(CC) -shared -Wl,-soname,$(LIB_LINK_VERSION_FILE) \
              $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) \
                 $^ $(INTERNAL_LIBRARIES_DEPEND_UPON) \
                 $(SHARED_LD_POSTFLAGS); \
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
	  $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS	+= -fPIC
SHARED_LIBEXT	= .so

HAVE_BUNDLES	= yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS	+= -shared
ADDITIONAL_LDFLAGS += -rdynamic -Wl,-R/usr/pkg/lib -L/usr/pkg/lib -Wl,-R/usr/X11R6/lib -L/usr/X11R6/lib
ADDITIONAL_INCLUDE_DIRS += -I/usr/pkg/include
STATIC_LDFLAGS += -static
endif
#
# end DragonFly
#
####################################################

####################################################
#
# OpenBSD 3.x (though set for 3.3)
#
ifeq ($(findstring openbsd, $(GNUSTEP_TARGET_OS)), openbsd)
HAVE_SHARED_LIBS        = yes
SHARED_LIB_LINK_CMD = \
	$(CC) -shared -Wl,-soname,$(LIB_LINK_SONAME_FILE) \
	   $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ \
	   $(INTERNAL_LIBRARIES_DEPEND_UPON) \
	   $(SHARED_LD_POSTFLAGS);\
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
	  $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE))
AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
	  $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)

OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS   += -fPIC
SHARED_LIBEXT   = .so

HAVE_BUNDLES    = yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS  += -shared -fPIC
ADDITIONAL_LDFLAGS += -Wl,-E
STATIC_LDFLAGS += -static

# nm on OpenBSD is rather like on Darwin
EXTRACT_CLASS_NAMES_COMMAND = nm  -g $$object_file | sed -n -e '/[^U] __objc_class_name_/ {s/[0-9a-f]* [^U] __objc_class_name_//p;}'
endif
#
# end OpenBSD 3.x
#
####################################################

####################################################
#
# OSF
#
ifeq ($(findstring osf, $(GNUSTEP_TARGET_OS)), osf)
HAVE_SHARED_LIBS	= yes
SHARED_LIB_LINK_CMD = \
	$(CC) -shared -Wl,-soname,$(LIB_LINK_VERSION_FILE) \
	   $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ ;\
	(cd $(LIB_LINK_OBJ_DIR); \
	  $(RM_LN_S) $(LIB_LINK_FILE); \
	  $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))
OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS	+= -fPIC
SHARED_LIBEXT	= .so

HAVE_BUNDLES	= yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS	+= -shared
ADDITIONAL_LDFLAGS += -rdynamic
STATIC_LDFLAGS += -static
# Newer gcc's don't define this in Objective-C programs:
AUXILIARY_CPPFLAGS += -D__LANGUAGES_C__
endif
#
# end OSF
#
####################################################

####################################################
#
# IRIX
#
ifeq ($(findstring irix, $(GNUSTEP_TARGET_OS)), irix)
HAVE_SHARED_LIBS        = yes

SHARED_LIB_LINK_CMD     = \
        $(CC) $(SHARED_LD_PREFLAGS) -shared -Wl,-soname,$(LIB_LINK_SONAME_FILE) \
           $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ \
           -Wl,-rpath,$(LIB_LINK_INSTALL_DIR) \
	   $(INTERNAL_LIBRARIES_DEPEND_UPON) \
	   $(SHARED_LD_POSTFLAGS);\
	(cd $(LIB_LINK_OBJ_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CHOWN = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	chown $(CHOWN_TO) $(LIB_LINK_SONAME_FILE); \
	chown $(CHOWN_TO) $(LIB_LINK_FILE))

SHARED_CFLAGS     += -fPIC
SHARED_LIBEXT   = .so

OBJ_MERGE_CMD		= \
	/usr/bin/ld -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

ADDITIONAL_LDFLAGS +=
STATIC_LDFLAGS +=

HAVE_BUNDLES    = yes
BUNDLE_LD       = $(CC)
BUNDLE_LDFLAGS  += -shared
endif

# end IRIX
#
####################################################

####################################################
#
# Mingw32
#
ifeq ($(findstring mingw32, $(GNUSTEP_TARGET_OS)), mingw32)
shared = yes
HAVE_SHARED_LIBS = yes
# This command links the library, generates automatically the list of
# symbols to export, creates the DLL (eg, obj/gnustep-base.dll) and 
# the import library (eg, obj/libgnustep-base.dll.a).
SHARED_LIB_LINK_CMD     = \
        $(CC) $(SHARED_LD_PREFLAGS) -shared \
        -Wl,--enable-auto-image-base \
        -Wl,--out-implib,$(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) \
           $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_DLL_FILE) $^ \
	   $(INTERNAL_LIBRARIES_DEPEND_UPON) \
	   $(SHARED_LD_POSTFLAGS)

AFTER_INSTALL_SHARED_LIB_CMD = 
AFTER_INSTALL_SHARED_LIB_CHOWN =

BUILD_DLL	 = yes
LIBEXT	 	 = .a
# Technically, in this Unix-inspired building system, a DLL is
# composed of a .dll file which goes in the executable path and is the
# one which is loaded at runtime, and a .dll.a file which goes in the
# library path and which is linked into the application in order to
# enable it use the .dll.  Anything in gnustep-make which is looking
# for shared libs should detect / look for the .dll.a as that's what
# we link applications against.
SHARED_LIBEXT    = .dll.a
DLL_LIBEXT	 = .dll
#SHARED_CFLAGS	 += 

OBJ_MERGE_CMD = \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

HAVE_BUNDLES   = yes
BUNDLE_LD      = $(CC)
BUNDLE_LDFLAGS     += -shared -Wl,--enable-auto-image-base
ADDITIONAL_LDFLAGS += -Wl,--enable-auto-import

# On Mingw32, it looks like the class name symbols start with '___' rather 
# than '__'
EXTRACT_CLASS_NAMES_COMMAND = nm -Pg $$object_file | sed -n -e '/^___objc_class_name_[A-Za-z_.]* [^U]/ {s/^___objc_class_name_\([A-Za-z_.]*\) [^U].*/\1/p;}'

endif

# end Mingw32
#
####################################################

####################################################
#
# Cygwin
#
ifeq ($(findstring cygwin, $(GNUSTEP_TARGET_OS)), cygwin)
shared = yes
HAVE_SHARED_LIBS = yes
# This command links the library, generates automatically the list of
# symbols to export, creates the DLL (eg, obj/gnustep-base.dll) and 
# the import library
SHARED_LIB_LINK_CMD     = \
        $(CC) $(SHARED_LD_PREFLAGS) -shared -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_DLL_FILE) \
	-Wl,--out-implib=$(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) \
	-Wl,--export-all-symbols \
	-Wl,--enable-auto-import \
	-Wl,--whole-archive $(OBJ_FILES_TO_LINK) $(ALL_LDFLAGS) \
	-Wl,--no-whole-archive $(INTERNAL_LIBRARIES_DEPEND_UPON) $(TARGET_SYSTEM_LIBS)\
	$(SHARED_LD_POSTFLAGS)
	
AFTER_INSTALL_SHARED_LIB_CMD = 
AFTER_INSTALL_SHARED_LIB_CHOWN =
SHARED_LIBEXT	 = .dll.a

BUILD_DLL	 = yes
CYGWIN_DLL_SUPPORT  = yes
#SHARED_LIBEXT	 = .a
DLL_LIBEXT	 = .dll
REBASE 		 = rebase 
REBASE_FLAGS = -d -b 0x68000000 -o 0x10000
CYGWIN_LD_FLAGS = -Wl,--export-all-symbols -Wl,--enable-auto-import
#SHARED_CFLAGS	 += 

OBJ_MERGE_CMD = \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) $(CYGWIN_LD_FLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

HAVE_BUNDLES   = yes
BUNDLE_LD      = $(CC)
BUNDLE_LDFLAGS += -shared -Wl,--export-all-symbols \
	-Wl,--enable-auto-import \
	-Wl,--whole-archive
BUNDLE_LIBFLAGS += -Wl,--no-whole-archiv
BUNDLE_LINK_CMD  = \
        $(BUNDLE_LD) $(BUNDLE_LDFLAGS) $(ALL_LDFLAGS) \
	-o $(LDOUT)$(BUNDLE_FILE) \
	$(OBJ_FILES_TO_LINK) \
	$(BUNDLE_LIBFLAGS) $(ALL_BUNDLE_LIBS); \
	$(REBASE) $(REBASE_FLAGS) $(BUNDLE_FILE)
endif

# end Cygwin
#
####################################################


####################################################
#
# Solaris
#
ifeq ($(findstring solaris, $(GNUSTEP_TARGET_OS)), solaris)
HAVE_SHARED_LIBS        = yes
SHARED_LIB_LINK_CMD     = \
	$(CC) $(SHARED_LD_PREFLAGS) -G -Wl,-h,$(LIB_LINK_SONAME_FILE) \
	   $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ \
	   $(INTERNAL_LIBRARIES_DEPEND_UPON) \
	   $(SHARED_LD_POSTFLAGS);\
	(cd $(LIB_LINK_OBJ_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CMD = \
	(cd $(LIB_LINK_INSTALL_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          if [ "$(LIB_LINK_SONAME_FILE)" != "$(LIB_LINK_VERSION_FILE)" ]; then\
            $(RM_LN_S) $(LIB_LINK_SONAME_FILE);\
            $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_SONAME_FILE); \
          fi; \
          $(LN_S) $(LIB_LINK_SONAME_FILE) $(LIB_LINK_FILE); \
	)
AFTER_INSTALL_SHARED_LIB_CHOWN = \
	(cd $(LIB_LINK_INSTALL_DIR); \
	chown $(CHOWN_TO) $(LIB_LINK_SONAME_FILE); \
	chown $(CHOWN_TO) $(LIB_LINK_FILE))

OBJ_MERGE_CMD		= \
	$(CC) -nostdlib -r $(ALL_LDFLAGS) -o $(GNUSTEP_OBJ_DIR)/$(SUBPROJECT_PRODUCT) $^ ;

SHARED_CFLAGS     += -fpic -fPIC
SHARED_LIBEXT   = .so

HAVE_BUNDLES    = yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS  = -shared -mimpure-text
#BUNDLE_LDFLAGS  = -nodefaultlibs -Xlinker -r
endif

# end Solaris
#
####################################################


####################################################
#
# Unixware
#
ifeq ($(findstring sysv4.2, $(GNUSTEP_TARGET_OS)), sysv4.2)
HAVE_SHARED_LIBS        = yes
SHARED_LIB_LINK_CMD     = \
        $(CC) $(SHARED_LD_PREFLAGS) -shared $(ALL_LDFLAGS) -o $(LIB_LINK_VERSION_FILE) $^ \
	  $(SHARED_LD_POSTFLAGS);\
        mv $(LIB_LINK_VERSION_FILE) $(LIB_LINK_OBJ_DIR);\
        (cd $(LIB_LINK_OBJ_DIR); \
          $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))

SHARED_CFLAGS     += -fpic -fPIC
SHARED_LIBEXT   = .so

HAVE_BUNDLES    = yes
BUNDLE_LD       = $(CC)
#BUNDLE_LDFLAGS  += -shared -mimpure-text
BUNDLE_LDFLAGS  += -nodefaultlibs -Xlinker -r
endif

# end Unixware
#
####################################################


####################################################
#
# HP-UX 
#
ifeq ($(findstring hpux, $(GNUSTEP_TARGET_OS)), hpux)
HAVE_SHARED_LIBS        = yes
SHARED_LIB_LINK_CMD     = \
        (cd $(LIB_LINK_OBJ_DIR); \
	  $(CC) $(SHARED_LD_PREFLAGS) \
	    -v $(SHARED_CFLAGS) -shared \
	    $(ALL_LDFLAGS) -o $(LIB_LINK_VERSION_FILE) `ls -1 *\.o */*\.o` \
	    $(SHARED_LD_POSTFLAGS) ;\
          $(RM_LN_S) $(LIB_LINK_FILE); \
          $(LN_S) $(LIB_LINK_VERSION_FILE) $(LIB_LINK_FILE))

ifeq ($(CC), cc)
SHARED_CFLAGS   += +z
else
SHARED_CFLAGS   += -fPIC
endif

ifeq ($(GNUSTEP_HOST_CPU), ia64)
SHARED_LIBEXT   = .so
else
SHARED_LIBEXT   = .sl
endif

HAVE_BUNDLES    = yes
BUNDLE_LD	= $(CC)
BUNDLE_LDFLAGS  += -nodefaultlibs -Xlinker -r
ADDITIONAL_LDFLAGS += -Xlinker +s
STATIC_LDFLAGS += -static
endif

# end HP-UX
#
####################################################
