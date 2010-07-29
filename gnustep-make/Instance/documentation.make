#   -*-makefile-*-
#   Instance/documentation.make
#
#   Instance Makefile rules to build GNUstep-based documentation.
#
#   Copyright (C) 1998, 2000, 2001, 2002 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
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
# The names of the documents are in the DOCUMENT_NAME variable.
# These final documents will be generated in info, dvi, ps, and html output.
#
# The names of text documents are in the DOCUMENT_TEXT_NAME variable.
#
# The main file for text document is in the xxx_TEXT_MAIN variable.
# Files already ready to be installed without pre-processing (eg, html, rtf)
#                                         are in the xxx_INSTALL_FILES
# The Texinfo files that needs pre-processing are in xxx_TEXI_FILES
# The GSDoc files that needs pre-processing are in xxx_GSDOC_FILES
# The files for processing by autogsdoc are in xxx_AGSDOC_FILES
# The options for controlling autogsdoc are in xxx_AGSDOC_FLAGS
#
# Javadoc support: 
# The Java classes and packages that needs documenting using javadoc
# are in xxx_JAVADOC_FILES (could contain both packages, as
# `gnu.gnustep.base', and standalone classes, as
# `gnu.gnustep.base.NSArray.java')
#
# The sourcepath to the Java classes source code in in xxx_JAVADOC_SOURCEPATH 
#   (it can contain more than one path, as CLASSPATH or LD_LIBRARY_PATH do).
# To set special flags for javadoc (eg, -public), use ADDITIONAL_JAVADOCFLAGS
#
# The installation directory is in the xxx_DOC_INSTALL_DIR variable
# (eg, Gui_DOC_INSTALL_DIR = Developer/Gui/Reference
#  Things should be installed under `Developer/YourProjectName' or 
#  `User/YourProjectName' - for Javadoc, use `Developer/YourProjectName' or 
#   `Developer/YourProjectName/Java' if your project has both java and 
#   non java)
#
#	Where xxx is the name of the document
#

TEXI_FILES = $($(GNUSTEP_INSTANCE)_TEXI_FILES)
GSDOC_FILES = $($(GNUSTEP_INSTANCE)_GSDOC_FILES)
AGSDOC_FILES = $($(GNUSTEP_INSTANCE)_AGSDOC_FILES)
LATEX_FILES = $($(GNUSTEP_INSTANCE)_LATEX_FILES)
JAVADOC_FILES = $($(GNUSTEP_INSTANCE)_JAVADOC_FILES)
DOC_INSTALL_DIR = $($(GNUSTEP_INSTANCE)_DOC_INSTALL_DIR)
TEXT_MAIN = $($(GNUSTEP_INSTANCE)_TEXT_MAIN)

#
# GNUSTEP_DVIPS is here because it's common to texi.make and latex.make
#

# To override GNUSTEP_DVIPS, define it differently in
# GNUmakefile.preamble
ifeq ($(GNUSTEP_DVIPS),)
  GNUSTEP_DVIPS = dvips
endif

# To override GNUSTEP_DVIPS_FLAGS, define it differently in
# GNUmakefile.premable.  To only add new flags to the existing ones,
# set ADDITIONAL_DVIPS_FLAGS in GNUmakefile.preamble.
ifeq ($(GNUSTEP_DVIPS_FLAGS),)
  GNUSTEP_DVIPS_FLAGS =
endif

.PHONY: internal-doc-all_ \
        internal-doc-clean \
        internal-doc-distclean \
        internal-doc-install_ \
        internal-doc-uninstall_ \
        internal-textdoc-all_ \
        internal-textdoc-clean \
        internal-textdoc-distclean \
        internal-textdoc-install_ \
        internal-textdoc-uninstall_

#
# Common code. 
#

# Installation directory - always created.  This rule should be before
# the makefile fragments' internal-doc-install_, so that
# GNUSTEP_DOCUMENTATION/DOC_INSTALL_DIR is built before their targets
# are.  FIXME: Maybe this dependency should be in the submakefiles
# themselves.
internal-doc-install_:: $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)

$(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)$(END_ECHO)

$(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)/$(GNUSTEP_INSTANCE):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)/$(GNUSTEP_INSTANCE)$(END_ECHO)

ifneq ($(TEXI_FILES),)
  include $(GNUSTEP_MAKEFILES)/Instance/Documentation/texi.make
endif

ifneq ($(GSDOC_FILES),)
  include $(GNUSTEP_MAKEFILES)/Instance/Documentation/gsdoc.make
endif

ifneq ($(AGSDOC_FILES),)
  include $(GNUSTEP_MAKEFILES)/Instance/Documentation/autogsdoc.make
endif

ifneq ($(LATEX_FILES),)
  include $(GNUSTEP_MAKEFILES)/Instance/Documentation/latex.make
endif

ifneq ($(JAVADOC_FILES),)
  include $(GNUSTEP_MAKEFILES)/Instance/Documentation/javadoc.make
endif

ifneq ($($(GNUSTEP_INSTANCE)_INSTALL_FILES),)
  include $(GNUSTEP_MAKEFILES)/Instance/Documentation/install_files.make
endif

#
# textdoc targets - these are meant to be used with texi.make ... maybe
# they should be moved in there
#
internal-textdoc-install_:: $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)
	$(ECHO_NOTHING)$(INSTALL_DATA) $(GNUSTEP_INSTANCE) \
	                $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)$(END_ECHO)

internal-textdoc-uninstall_::
	$(ECHO_UNINSTALLING)rm -f \
          $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)/$(GNUSTEP_INSTANCE)$(END_ECHO)

internal-textdoc-clean::
	$(ECHO_NOTHING) rm -f $(GNUSTEP_INSTANCE) $(END_ECHO)

internal-textdoc-distclean::

