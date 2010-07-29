#
#   rules.make
#
#   Makefile rules for the Instance invocation.
#
#   Copyright (C) 1997, 2001, 2002 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
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


# Every project should have its internal-xxx-all depend first on
# before-$(GNUSTEP_INSTANCE)-all, and last on
# after-$(GNUSTEP_INSTANCE)-all.  We declare them here, empty, so that
# the user can add them if he wants, but if he doesn't, make doesn't
# complain about missing targets.

# NB: internal-$(GNUSTEP_TYPE)-all_ should not be declared .PHONY
# here, because it's not implemented here.  (example of how could go
# wrong otherwise: if say internal-clibrary-all_ depends on
# internal-library-all_, both of them should be declared .PHONY, while
# here we would only declare one of them .PHONY, so it should be done
# by the project specific makefile fragments).
.PHONY: \
 before-$(GNUSTEP_INSTANCE)-all after-$(GNUSTEP_INSTANCE)-all \
 internal-$(GNUSTEP_TYPE)-all \
 before-$(GNUSTEP_INSTANCE)-install after-$(GNUSTEP_INSTANCE)-install \
 internal-$(GNUSTEP_TYPE)-install \
 before-$(GNUSTEP_INSTANCE)-uninstall after-$(GNUSTEP_INSTANCE)-uninstall \
 internal-$(GNUSTEP_TYPE)-uninstall

# By adding the line
#   xxx_COPY_INTO_DIR = ../Vanity.framework/Resources
# to you GNUmakefile, you cause the after-xxx-all:: stage of
# compilation of xxx to copy the created stuff into the *local*
# directory ../Vanity.framework/Resources (this path should be
# relative).  It also disables installation of xxx.
#
# This is normally used, for example, to bundle a tool into a
# framework.  You compile the framework, then the tool, then you can
# request the tool to be copied into the framework, becoming part of
# the framework (it is installed with the framework etc).
#
COPY_INTO_DIR = $(strip $($(GNUSTEP_INSTANCE)_COPY_INTO_DIR))

# If COPY_INTO_DIR is non-empty, we'll execute below an additional
# target at the end of compilation:
# internal-$(GNUSTEP_TYPE)-copy_into_dir

# Centrally disable standard installation if COPY_INTO_DIR is non-empty.
ifneq ($(COPY_INTO_DIR),)
  $(GNUSTEP_INSTANCE)_STANDARD_INSTALL = no
endif

before-$(GNUSTEP_INSTANCE)-all::

after-$(GNUSTEP_INSTANCE)-all::

# Automatically run before-$(GNUSTEP_INSTANCE)-all before building,
# and after-$(GNUSTEP_INSTANCE)-all after building.
# The project-type specific makefile instance fragment only needs to provide
# the internal-$(GNUSTEP_TYPE)-all_ rule.

ifeq ($(COPY_INTO_DIR),)
internal-$(GNUSTEP_TYPE)-all:: before-$(GNUSTEP_INSTANCE)-all \
                               internal-$(GNUSTEP_TYPE)-all_  \
                               after-$(GNUSTEP_INSTANCE)-all
else
internal-$(GNUSTEP_TYPE)-all:: before-$(GNUSTEP_INSTANCE)-all \
                               internal-$(GNUSTEP_TYPE)-all_  \
                               after-$(GNUSTEP_INSTANCE)-all \
                               internal-$(GNUSTEP_TYPE)-copy_into_dir

# To copy into a dir, we always have to first make sure the dir exists :-)
$(COPY_INTO_DIR):
	$(ECHO_CREATING)$(MKDIRS) $@$(END_ECHO)

# The specific project-type makefiles will add more commands.
internal-$(GNUSTEP_TYPE)-copy_into_dir:: $(COPY_INTO_DIR)
endif

before-$(GNUSTEP_INSTANCE)-install::

after-$(GNUSTEP_INSTANCE)-install::

before-$(GNUSTEP_INSTANCE)-uninstall::

after-$(GNUSTEP_INSTANCE)-uninstall::

# By adding the line 
#   xxxx_STANDARD_INSTALL = no
# to your GNUmakefile, you can disable the standard installation code
# for a certain GNUSTEP_INSTANCE.  This can be useful if you are
# installing manually in some other way (or for some other reason you
# don't want installation to be performed ever) and don't want the
# standard installation to be performed.  Please note that
# before-xxx-install and after-xxx-install are still executed, so if
# you want, you can add your code in those targets to perform your
# custom installation.

ifeq ($($(GNUSTEP_INSTANCE)_STANDARD_INSTALL),no)

internal-$(GNUSTEP_TYPE)-install:: before-$(GNUSTEP_INSTANCE)-install \
                                   after-$(GNUSTEP_INSTANCE)-install
	@echo "Skipping standard installation of $(GNUSTEP_INSTANCE) as requested by makefile"

internal-$(GNUSTEP_TYPE)-uninstall:: before-$(GNUSTEP_INSTANCE)-uninstall \
                                     after-$(GNUSTEP_INSTANCE)-uninstall
	@echo "Skipping standard uninstallation of $(GNUSTEP_INSTANCE) as requested by makefile"

else

# By adding an ADDITIONAL_INSTALL_DIRS variable (or xxx_INSTALL_DIRS)
# you can request additional installation directories to be created
# before the first installation target is executed.
ADDITIONAL_INSTALL_DIRS += $($(GNUSTEP_INSTANCE)_INSTALL_DIRS)

$(ADDITIONAL_INSTALL_DIRS):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-$(GNUSTEP_TYPE)-install:: $(ADDITIONAL_INSTALL_DIRS) \
                                   before-$(GNUSTEP_INSTANCE)-install \
                                   internal-$(GNUSTEP_TYPE)-install_  \
                                   after-$(GNUSTEP_INSTANCE)-install

# It would be nice to remove ADDITIONAL_INSTALL_DIRS here, if empty.
internal-$(GNUSTEP_TYPE)-uninstall:: before-$(GNUSTEP_INSTANCE)-uninstall \
                                   internal-$(GNUSTEP_TYPE)-uninstall_  \
                                   after-$(GNUSTEP_INSTANCE)-uninstall

endif

# before-$(GNUSTEP_INSTANCE)-clean and similar for after and distclean
# are not supported -- they wouldn't be executed most of the times, since
# most of the times we don't perform an Instance invocation at all on
# make clean or make distclean.


#
# The list of Objective-C source files to be compiled
# are in the OBJC_FILES variable.
#
# The list of C source files to be compiled
# are in the C_FILES variable.
#
# The list of C++ source files to be compiled
# are in the CC_FILES variable.
#
# The list of Objective-C++ source files to be compiled
# are in the OBJCC_FILES variable.
#
# The list of PSWRAP source files to be compiled
# are in the PSWRAP_FILES variable.
#
# The list of JAVA source files to be compiled
# are in the JAVA_FILES variable.
#
# The list of JAVA source files from which to generate jni headers
# are in the JAVA_JNI_FILES variable.
#
# This list of WINDRES source files to be compiled
# are in the WINDRES_FILES variable.
# 

#
# Please note the subtle difference:
#
# At `user' level (ie, in the user's GNUmakefile), 
# the SUBPROJECTS variable is reserved for use with aggregate.make; 
# the xxx_SUBPROJECTS variable is reserved for use with subproject.make.
#
# This separation *must* be enforced strictly, because nothing prevents 
# a GNUmakefile from including both aggregate.make and subproject.make!
#

ifneq ($($(GNUSTEP_INSTANCE)_SUBPROJECTS),)
SUBPROJECT_OBJ_FILES = $(foreach d, $($(GNUSTEP_INSTANCE)_SUBPROJECTS), \
    $(addprefix $(GNUSTEP_BUILD_DIR)/$(d)/, $(GNUSTEP_OBJ_DIR_NAME)/$(SUBPROJECT_PRODUCT)))
endif

OBJC_OBJS = $(patsubst %.m,%$(OEXT),$($(GNUSTEP_INSTANCE)_OBJC_FILES))
OBJC_OBJ_FILES = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(OBJC_OBJS))

OBJCC_OBJS = $(patsubst %.mm,%$(OEXT),$($(GNUSTEP_INSTANCE)_OBJCC_FILES))
OBJCC_OBJ_FILES = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(OBJCC_OBJS))

JAVA_OBJS = $(patsubst %.java,%.class,$($(GNUSTEP_INSTANCE)_JAVA_FILES))
JAVA_OBJ_FILES = $(JAVA_OBJS)

JAVA_JNI_OBJS = $(patsubst %.java,%.h,$($(GNUSTEP_INSTANCE)_JAVA_JNI_FILES))
JAVA_JNI_OBJ_FILES = $(JAVA_JNI_OBJS)

PSWRAP_C_FILES = $(patsubst %.psw,%.c,$($(GNUSTEP_INSTANCE)_PSWRAP_FILES))
PSWRAP_H_FILES = $(patsubst %.psw,%.h,$($(GNUSTEP_INSTANCE)_PSWRAP_FILES))
PSWRAP_OBJS = $(patsubst %.psw,%$(OEXT),$($(GNUSTEP_INSTANCE)_PSWRAP_FILES))
PSWRAP_OBJ_FILES = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(PSWRAP_OBJS))

C_OBJS = $(patsubst %.c,%$(OEXT),$($(GNUSTEP_INSTANCE)_C_FILES))
C_OBJ_FILES = $(PSWRAP_OBJ_FILES) $(addprefix $(GNUSTEP_OBJ_DIR)/,$(C_OBJS))

# C++ files might end in .C, .cc, .cpp, .cxx, .cp so we replace multiple times
CC_OBJS = $(patsubst %.cc,%$(OEXT),\
           $(patsubst %.C,%$(OEXT),\
            $(patsubst %.cp,%$(OEXT),\
             $(patsubst %.cpp,%$(OEXT),\
              $(patsubst %.cxx,%$(OEXT),$($(GNUSTEP_INSTANCE)_CC_FILES))))))
CC_OBJ_FILES = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(CC_OBJS))

ifeq ($(findstring mingw32, $(GNUSTEP_TARGET_OS)), mingw32)
  WINDRES_OBJS = $(patsubst %.rc,%$(OEXT),$($(GNUSTEP_INSTANCE)_WINDRES_FILES))
  WINDRES_OBJ_FILES = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(WINDRES_OBJS))
else
ifeq ($(findstring cygwin, $(GNUSTEP_TARGET_OS)), cygwin)
  WINDRES_OBJS = $(patsubst %.rc,%$(OEXT),$($(GNUSTEP_INSTANCE)_WINDRES_FILES))
  WINDRES_OBJ_FILES = $(addprefix $(GNUSTEP_OBJ_DIR)/,$(WINDRES_OBJS))
else
  WINDRES_OBJ_FILES =
endif
endif

OBJ_FILES = $($(GNUSTEP_INSTANCE)_OBJ_FILES)

# OBJ_FILES_TO_LINK is the set of all .o files which will be linked
# into the result - please note that you can add to OBJ_FILES_TO_LINK
# by defining manually some special xxx_OBJ_FILES for your
# tool/app/whatever.  Strip the variable so that by comparing
# OBJ_FILES_TO_LINK to '' we know if there is a link stage to be
# performed at all (useful for example in bundles which can contain an
# object file, or not).
OBJ_FILES_TO_LINK = $(strip $(C_OBJ_FILES) $(OBJC_OBJ_FILES) $(CC_OBJ_FILES) $(OBJCC_OBJ_FILES) $(WINDRES_OBJ_FILES) $(SUBPROJECT_OBJ_FILES) $(OBJ_FILES))

ifeq ($(AUTO_DEPENDENCIES),yes)
  ifneq ($(strip $(OBJ_FILES_TO_LINK)),)
    -include $(addsuffix .d, $(basename $(OBJ_FILES_TO_LINK)))
  endif
endif


##
## Library and related special flags.
##
BUNDLE_LIBS += $($(GNUSTEP_INSTANCE)_BUNDLE_LIBS)

ADDITIONAL_INCLUDE_DIRS += $($(GNUSTEP_INSTANCE)_INCLUDE_DIRS)

ADDITIONAL_GUI_LIBS += $($(GNUSTEP_INSTANCE)_GUI_LIBS)

ADDITIONAL_TOOL_LIBS += $($(GNUSTEP_INSTANCE)_TOOL_LIBS)

ADDITIONAL_OBJC_LIBS += $($(GNUSTEP_INSTANCE)_OBJC_LIBS)

ADDITIONAL_LIBRARY_LIBS += $($(GNUSTEP_INSTANCE)_LIBS) \
                           $($(GNUSTEP_INSTANCE)_LIBRARY_LIBS)

ADDITIONAL_NATIVE_LIBS += $($(GNUSTEP_INSTANCE)_NATIVE_LIBS)

ADDITIONAL_LIB_DIRS += $($(GNUSTEP_INSTANCE)_LIB_DIRS)

ADDITIONAL_CPPFLAGS += $($(GNUSTEP_INSTANCE)_CPPFLAGS)

ADDITIONAL_CFLAGS += $($(GNUSTEP_INSTANCE)_CFLAGS)

ADDITIONAL_OBJCFLAGS += $($(GNUSTEP_INSTANCE)_OBJCFLAGS)

ADDITIONAL_CCFLAGS += $($(GNUSTEP_INSTANCE)_CCFLAGS)

ADDITIONAL_OBJCCFLAGS += $($(GNUSTEP_INSTANCE)_OBJCCFLAGS)

ADDITIONAL_LDFLAGS += $($(GNUSTEP_INSTANCE)_LDFLAGS)

ADDITIONAL_CLASSPATH += $($(GNUSTEP_INSTANCE)_CLASSPATH)

LIBRARIES_DEPEND_UPON += $($(GNUSTEP_INSTANCE)_LIBRARIES_DEPEND_UPON)

