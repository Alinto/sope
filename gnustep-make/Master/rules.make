#   -*-makefile-*-
#   rules.make
#
#   Makefile rules for the Master invocation.
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

#
# Quick explanation - 
#
# Say that you run `make all'.  The rule for `all' is below here, and
# depends on internal-all.  Rules for internal-all are found in
# tool.make, library.make etc; there, internal-all will depend on a
# list of appropriate %.variables targets, such as
# gsdoc.tool.all.variables <which means we need to make `all' for the
# `tool' called `gsdoc'> - to process these prerequisites, the
# %.variables rule below is used.  this rule gets an appropriate make
# subprocess going, with the task of building that specific
# instance-type-operation prerequisite.  The make subprocess will be run
# as in `make internal-tool-all INTERNAL_tool_NAME=gsdoc ...<and other
# variables>' and this make subprocess wil find the internal-tool-all
# rule in tool.make, and execute that, building the tool.
#
# Hint: run make with `make -n' to see the recursive method invocations 
#       with the parameters used
#

#
# Global targets
#

# The first time you invoke `make', if you have not given a target,
# `all' is executed as it is the first one.  If a GNUSTEP_BUILD_DIR is
# specifed, make sure to create it before anything else is done.
ifeq ($(GNUSTEP_BUILD_DIR),.)
all:: before-all internal-all after-all
else
all:: $(GNUSTEP_BUILD_DIR) before-all internal-all after-all
endif

# internal-after-install is used by packaging to get the list of files 
# installed (see rpm.make); it must come after *all* the installation 
# rules have been executed.
# internal-check-installation-permissions comes before everything so
# that we run any command if we aren't allowed to install
# install depends on all as per GNU/Unix habits, conventions and standards.

# The very first top-most make invocation we want to have install
# depend on internal-check-install-permissions and on all, and
# distclean depend on clean.  We used to check MAKELEVEL=0 here to
# determine if this is the top-most invocation of make, but that does
# not work if the top-most invocation of make is done from within a
# (non-gnustep-make) makefile itself!  So we use a marker variable.
# _GNUSTEP_TOP_INVOCATION_DONE is not set the very first / top-most
# make invocation , but we set it for all sub-invocations, so all
# subinvocations will have it set and we can distinguish them.
ifeq ($(_GNUSTEP_TOP_INVOCATION_DONE),)
# Top-most invocation of make
install:: internal-check-install-permissions all \
          before-install internal-install after-install internal-after-install

distclean:: clean before-distclean internal-distclean after-distclean

# Further make invocations will have this variable set
export _GNUSTEP_TOP_INVOCATION_DONE = 1
else
#  Sub-invocation of make
install:: before-install internal-install after-install internal-after-install

distclean:: before-distclean internal-distclean after-distclean
endif


uninstall:: before-uninstall internal-uninstall after-uninstall

clean:: before-clean internal-clean after-clean

check:: before-check internal-check after-check

strings:: before-strings internal-strings after-strings

#
# Placeholders for internal targets
#

before-all::

internal-all::

after-all::

# In case of problems, we print a message trying to educate the user
# about how to install elsewhere, except if the installation dir is
# GNUSTEP_SYSTEM_ROOT, in that case we don't want to suggest to
# install the software elsewhere, because it is likely to be system
# software like the gnustep-base library.  NB: the check of
# GNUSTEP_INSTALLATION_DIR against GNUSTEP_SYSTEM_ROOT is not perfect
# as /usr/GNUstep/System/ might not match /usr/GNUstep/System (note
# the missing '/' at the end) but what we really want to catch is the
# GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT) command in the
# makefiles, and the check of course works with it.
internal-check-install-permissions:
	@if [ -d "$(GNUSTEP_INSTALLATION_DIR)" \
	      -a ! -w "$(GNUSTEP_INSTALLATION_DIR)" ]; then \
	  echo "*ERROR*: the software is configured to install itself into $(GNUSTEP_INSTALLATION_DIR)"; \
	  echo "but you do not have permissions to write in that directory:";\
	  echo "Aborting installation."; \
	  echo ""; \
	  if [ "$(GNUSTEP_INSTALLATION_DIR)" != "$(GNUSTEP_SYSTEM_ROOT)" ]; then \
	    echo "Suggestion: if you can't get permissions to install there, you can try";\
	    echo "to install the software in a different directory by setting";\
	    echo "GNUSTEP_INSTALLATION_DIR.  For example, to install into";\
	    echo "$(GNUSTEP_USER_ROOT), which is your own GNUstep directory, just type"; \
	    echo ""; \
	    echo "make install GNUSTEP_INSTALLATION_DIR=\"$(GNUSTEP_USER_ROOT)\""; \
	    echo ""; \
	    echo "You should always be able to install into $(GNUSTEP_USER_ROOT),";\
	    echo "so this might be a good option.  The other meaningful values for";\
	    echo "GNUSTEP_INSTALLATION_DIR on your system are:";\
	    echo "$(GNUSTEP_SYSTEM_ROOT) (the System directory)";\
	    echo "$(GNUSTEP_LOCAL_ROOT) (the Local directory)";\
	    echo "$(GNUSTEP_NETWORK_ROOT) (the Network directory)";\
	    echo "but you might need special permissions to install in those directories.";\
	  fi; \
	  exit 1; \
	fi

before-install::

internal-install::

after-install::

# The following for exclusive use of packaging code
internal-after-install::

before-uninstall::

internal-uninstall::

after-uninstall::

before-clean::

internal-clean::
	rm -rf $(GNUSTEP_BUILD_DIR)/*~ $(GNUSTEP_BUILD_DIR)/obj

after-clean::

before-distclean::

internal-distclean::
	rm -f $(GNUSTEP_BUILD_DIR)/core

after-distclean::

before-check::

internal-check::

after-check::

before-strings::

internal-strings::

after-strings::

# declare targets as PHONY

.PHONY: all before-all internal-all after-all \
	 install before-install internal-install after-install \
	         internal-after-install \
	 uninstall before-uninstall internal-uninstall after-uninstall \
	 clean before-clean internal-clean after-clean \
	 distclean before-distclean internal-distclean after-distclean \
	 check before-check internal-check after-check \
	 strings before-strings internal-strings after-strings

# Prevent make from trying to remove stuff like
# libcool.library.all.subprojects thinking that it is a temporary file
.PRECIOUS: %.variables %.subprojects

#
## The magical %.variables rules, thank you GNU make!
#

# The %.variables target has to be called with the name of the actual
# instance, followed by the operation, then the makefile fragment to be
# called and then the variables word. Suppose for example we build the
# library libgmodel, the target should look like:
#
#	libgmodel.all.library.variables
#
# when the rule is executed, $* is libgmodel.all.libray;
#  instance will be libgmodel
#  operation will be all
#  type will be library 
#
# this rule might be executed many times, for different targets to build.

# the rule then calls a submake, which runs the real code

# the following is the code used in %.variables and %.subprojects
# to extract the instance, operation and type from the $* (the stem) of the 
# rule.  with GNU make => 3.78, we could define the following as macros 
# and use $(call ...) to call them; but because we have users who are using 
# GNU make older than that, we have to manually `paste' this code 
# wherever we need to access instance or type or operation.
#
# Anyway, the following table tells you what these commands do - 
#
# instance=$(basename $(basename $(1)))
# operation=$(subst .,,$(suffix $(basename $(1))))
# type=$(subst -,_,$(subst .,,$(suffix $(1))))
#
# It's very important to notice that $(basename $(basename $*)) in
# these rules is simply the instance (such as libgmodel).

# NB: INTERNAL_$${type}_NAME and TARGET are deprecated - use
# GNUSTEP_INSTANCE instead.

# Before building the real thing, we must build the subprojects

# If we are at the very first make invocation, convert
# GNUSTEP_BUILD_DIR into an absolute path.  All other make invocations
# can then assume it is already an absolute path form, and avoid the
# shell invocation to convert into absolute path.  Let's avoid the
# shell invocation unless strictly necessary - it's slow.
ifeq ($(MAKELEVEL),0)
  ifneq ($(GNUSTEP_BUILD_DIR),.)

    # We can't use ':=' here (which we'd like, since it would guarantee
    # that the shell command is executed only once) because ':=' would
    # cause the shell command to be executed immediately, which is *now*
    # during parsing, before any rule has been executed; in particular,
    # before the rule which creates GNUSTEP_BUILD_DIR has been executed
    # (if it had to be executed), and that might cause the 'cd' in the
    # following shell command to fail.  So what we do, is we define this
    # as a simple variable with '=', which means it will be evaluated
    # every time it is used, but not before, and then we make sure to
    # use it as little as possible and only in rules which are executed
    # after the rule to build GNUSTEP_BUILD_DIR.  Please note that in
    # this setup, *any* reference to this variable causes a slow
    # subshell invocation.  At the moment, it's used when running
    # the subprojects/variables and when running the aggregate
    # projects.

    # That makes 1 invocation per type of project per type of target
    # used in the top-level makefile.  For example, if the top-level
    # makefile includes aggregate.make and documentation.make and does
    # a make all, we evaluate this variable twice.  If it does a make
    # distclean (which automatically invokes make clean as well) we
    # evaluate this variable 4 times.  All non-top-level make code 
    # is free from overhead.
    # In the rules which need the ABS_GNUSTEP_BUILD_DIR variable more
    # than once we copy it into a shell variable and reuse the shell
    # variable to avoid evaluating ABS_GNUSTEP_BUILD_DIR multiple
    # times in the same rule.
    # DO NOT EVER USE THIS VARIABLE UNLESS YOU FULLY UNDERSTAND THE
    # PERFORMANCE IMPLICATIONS JUST DESCRIBED.
    ABS_GNUSTEP_BUILD_DIR = $(shell (cd "$(GNUSTEP_BUILD_DIR)"; pwd))
  else
    ABS_GNUSTEP_BUILD_DIR = .
  endif
else
  ABS_GNUSTEP_BUILD_DIR = $(strip $(GNUSTEP_BUILD_DIR))
endif

# If you change the subprojects code here, make sure to update the
# %.subprojects rule below too!  The code from the %.subprojects rule
# below is 'inlined' here for speed (so that we don't run a separate
# shell just to execute that code).
%.variables:
	@ \
instance=$(basename $(basename $*)); \
operation=$(subst .,,$(suffix $(basename $*))); \
type=$(subst -,_,$(subst .,,$(suffix $*))); \
abs_build_dir="$(ABS_GNUSTEP_BUILD_DIR)"; \
if [ "$($(basename $(basename $*))_SUBPROJECTS)" != "" ]; then \
  echo Making $$operation in subprojects of $$type $$instance...; \
  for f in $($(basename $(basename $*))_SUBPROJECTS) __done; do \
    if [ $$f != __done ]; then       \
      mf=$(MAKEFILE_NAME); \
      if [ ! -f $$f/$$mf -a -f $$f/Makefile ]; then \
        mf=Makefile; \
        echo "WARNING: No $(MAKEFILE_NAME) found for subproject $$f; using 'Makefile'"; \
      fi; \
      if [ "$${abs_build_dir}" = "." ]; then \
        gsbuild="."; \
      else \
        gsbuild="$${abs_build_dir}/$$f"; \
      fi; \
      if [ "$(OWNING_PROJECT_HEADER_DIR_NAME)" = "" ]; then \
        if [ "$$type" = "framework" ]; then \
          if [ "$(FRAMEWORK_VERSION_SUPPORT)" = "yes" ]; then \
            framework_version="$($(basename $(basename $*))_CURRENT_VERSION_NAME)"; \
            if [ "$$framework_version" = "" ]; then framework_version="A"; fi; \
            owning_project_header_dir="../$${instance}.framework/Versions/$${framework_version}/Headers"; \
          else \
            owning_project_header_dir="../$${instance}.framework/Headers"; \
          fi; \
       else owning_project_header_dir=""; \
       fi; \
      else \
        owning_project_header_dir="../$(OWNING_PROJECT_HEADER_DIR_NAME)"; \
      fi; \
      if $(MAKE) -C $$f -f $$mf --no-keep-going $$operation \
          OWNING_PROJECT_HEADER_DIR_NAME="$${owning_project_header_dir}" \
          DERIVED_SOURCES="../$(DERIVED_SOURCES)" \
          GNUSTEP_BUILD_DIR="$$gsbuild" \
        ; then \
        :; \
      else exit $$?; \
      fi; \
    fi; \
  done; \
fi; \
echo Making $$operation for $$type $$instance...; \
$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory --no-keep-going \
    internal-$${type}-$$operation \
    GNUSTEP_TYPE=$$type \
    GNUSTEP_INSTANCE=$$instance \
    GNUSTEP_OPERATION=$$operation \
    INTERNAL_$${type}_NAME=$$instance \
    TARGET=$$instance \
    GNUSTEP_BUILD_DIR="$${abs_build_dir}"

#
# This rule provides exactly the same code as the %.variables one with
# respect to subprojects; it is available for clean targets when they
# want to run make clean in subprojects but do not need a full Instance
# invocation.  In that case, they can depend on %.subprojects only.
#
# NB: The OWNING_PROJECT_HEADER_DIR_NAME hack in this rule is sort of
# horrible, because it pollutes this general rule with code specific
# to the framework implementation (eg, where the framework headers are
# located).  Still, it's the least evil we could think of at the
# moment :-) The framework code is now completely confined into
# framework.make makefiles, except for this little hack in here.  It
# would be nice to remove this hack without loosing functionality (or
# polluting other general-purpose makefiles).
%.subprojects:
	@ \
instance=$(basename $(basename $*)); \
operation=$(subst .,,$(suffix $(basename $*))); \
type=$(subst -,_,$(subst .,,$(suffix $*))); \
abs_build_dir="$(ABS_GNUSTEP_BUILD_DIR)"; \
if [ "$($(basename $(basename $*))_SUBPROJECTS)" != "" ]; then \
  echo Making $$operation in subprojects of $$type $$instance...; \
  for f in $($(basename $(basename $*))_SUBPROJECTS) __done; do \
    if [ $$f != __done ]; then       \
      mf=$(MAKEFILE_NAME); \
      if [ ! -f $$f/$$mf -a -f $$f/Makefile ]; then \
        mf=Makefile; \
        echo "WARNING: No $(MAKEFILE_NAME) found for subproject $$f; using 'Makefile'"; \
      fi; \
      if [ "$${abs_build_dir}" = "." ]; then \
        gsbuild="."; \
      else \
        gsbuild="$${abs_build_dir}/$$f"; \
      fi; \
      if [ "$(OWNING_PROJECT_HEADER_DIR_NAME)" = "" ]; then \
        if [ "$$type" = "framework" ]; then \
          if [ "$(FRAMEWORK_VERSION_SUPPORT)" = "yes" ]; then \
            framework_version="$($(basename $(basename $*))_CURRENT_VERSION_NAME)"; \
            if [ "$$framework_version" = "" ]; then framework_version="A"; fi; \
            owning_project_header_dir="../$${instance}.framework/Versions/$${framework_version}/Headers"; \
          else \
            owning_project_header_dir="../$${instance}.framework/Headers"; \
          fi; \
       else owning_project_header_dir=""; \
       fi; \
      else \
        owning_project_header_dir="../$(OWNING_PROJECT_HEADER_DIR_NAME)"; \
      fi; \
      if $(MAKE) -C $$f -f $$mf --no-keep-going $$operation \
          OWNING_PROJECT_HEADER_DIR_NAME="$${owning_project_header_dir}" \
          DERIVED_SOURCES="../$(DERIVED_SOURCES)" \
          GNUSTEP_BUILD_DIR="$$gsbuild" \
        ; then \
        :; \
      else exit $$?; \
      fi; \
    fi; \
  done; \
fi

#
# Now rules for packaging - all automatically included
# 

PACKAGE_NAME := $(strip $(PACKAGE_NAME))

ifeq ($(PACKAGE_NAME),)
  # Use a default of unnamed-package if nothing better is provided.
  PACKAGE_NAME := unnamed-package
endif

# For backwards compatibility, take value of PACKAGE_VERSION from
# VERSION.  New GNUmakefiles should all use the PACKAGE_VERSION
# variable rather than the VERSION variable.
ifeq ($(PACKAGE_VERSION),)

  PACKAGE_VERSION = $(VERSION)

  # Use a default of 0.0.1 if nothing better is provided.
  ifeq ($(PACKAGE_VERSION),)
    PACKAGE_VERSION = 0.0.1
  endif

endif

#
# Rules for building source distributions
#
include $(GNUSTEP_MAKEFILES)/Master/source-distribution.make

#
# Rules for building spec files/file lists for RPMs, and RPMs
#
include $(GNUSTEP_MAKEFILES)/Master/rpm.make

#
# Rules for building debian/* scripts for DEBs, and DEBs
# 
#include $(GNUSTEP_MAKEFILES)/Master/deb.make <TODO>
