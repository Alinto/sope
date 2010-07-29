#
#   aggregate.make
#
#   Master Makefile rules to build a set of GNUstep-base subprojects.
#
#   Copyright (C) 1997-2002 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
#   Author:  Nicola Pero <n.pero@mi.flashnet.it>
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

ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

#
# The list of aggregate project directory names is in the makefile
# variable SUBPROJECTS.  The name is unforunate, because it is confusingly
# similar to xxx_SUBPROJECTS, which is used for subprojects.
#
# SUBPROJECTS - which is implemented in this file - are just a list of
# directories; we step in each directory in turn, and run a submake in
# there.  The project types in the directories can be anything -
# tools, documentation, libraries, bundles, applications, whatever.
# For example, if your package is composed by a library and then by
# some tools using the library, you could have the library in one
# directory, the tools in another directory, and have a top level
# GNUmakefile which has the two as SUBPROJECTS.
#
# xxx_SUBPROJECTS - which is *not* implemented in this file, I'm just
# explaining it here to make clear the difference - are again a list
# of directories, each of which should contain a *subproject* project
# type (as implemented by subproject.make), which builds stuff into a
# .o file, which is then automatically linked into the xxx instance by
# gnustep-make when the top-level xxx is built.  For example, a
# library might be broken into many separate subprojects, each of
# which implementing a logically separated part of the library; the
# top-level GNUmakefile will then build the library, specifying
# xxx_SUBPROJECTS for the library to be those directories.
# gnustep-make will step in all dirs, compile the subprojects, and
# then finally automatically link the subprojects into the main
# library.
SUBPROJECTS := $(strip $(SUBPROJECTS))

ifneq ($(SUBPROJECTS),)
internal-all internal-install internal-uninstall internal-clean \
  internal-distclean internal-check internal-strings::
	@ operation=$(subst internal-,,$@); \
	  abs_build_dir="$(ABS_GNUSTEP_BUILD_DIR)"; \
	for f in $(SUBPROJECTS); do \
	  echo "Making $$operation in $$f..."; \
	  mf=$(MAKEFILE_NAME); \
	  if [ ! -f "$$f/$$mf" -a -f "$$f/Makefile" ]; then \
	    mf=Makefile; \
	    echo "WARNING: No $(MAKEFILE_NAME) found for aggregate project $$f; using 'Makefile'"; \
	  fi; \
	  if [ "$${abs_build_dir}" = "." ]; then \
	    gsbuild="."; \
	  else \
	    gsbuild="$${abs_build_dir}/$$f"; \
	  fi; \
	  if $(MAKE) -C $$f -f $$mf --no-keep-going $$operation \
	       GNUSTEP_BUILD_DIR="$$gsbuild"; then \
	    :; else exit $$?; \
	  fi; \
	done
endif

