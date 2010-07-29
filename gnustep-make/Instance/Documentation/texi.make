#   -*-makefile-*-
#   Instance/Documentation/texi.make
#
#   Instance Makefile rules to build Texinfo documentation.
#
#   Copyright (C) 1998, 2000, 2001, 2002 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author: Nicola Pero <n.pero@mi.flashnet.it> 
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

# To override GNUSTEP_MAKEINFO, define it differently in
# GNUmakefile.preamble
ifeq ($(GNUSTEP_MAKEINFO),)
  GNUSTEP_MAKEINFO = makeinfo
endif

# To override GNUSTEP_MAKEINFO_FLAGS, define it differently in
# GNUmakefile.premable.  To only add new flags to the existing ones,
# set ADDITIONAL_MAKEINFO_FLAGS in GNUmakefile.preamble.
ifeq ($(GNUSTEP_MAKEINFO_FLAGS),)
  GNUSTEP_MAKEINFO_FLAGS = -D NO-TEXI2HTML
endif

ifeq ($(GNUSTEP_MAKETEXT),)
  GNUSTEP_MAKETEXT = makeinfo
endif
ifeq ($(GNUSTEP_MAKETEXT_FLAGS),)
  GNUSTEP_MAKETEXT_FLAGS = -D NO-TEXI2HTML -D TEXT-ONLY --no-header --no-split
endif

ifeq ($(GNUSTEP_TEXI2DVI),)
  GNUSTEP_TEXI2DVI = texi2dvi
endif
ifeq ($(GNUSTEP_TEXI2DVI_FLAGS),)
  GNUSTEP_TEXI2DVI_FLAGS =
endif

ifeq ($(GNUSTEP_TEXI2PDF),)
  GNUSTEP_TEXI2PDF = texi2pdf
endif
ifeq ($(GNUSTEP_TEXI2PDF_FLAGS),)
  GNUSTEP_TEXI2PDF_FLAGS =
endif

ifeq ($(GNUSTEP_TEXI2HTML),)
  GNUSTEP_TEXI2HTML = texi2html
endif
ifeq ($(GNUSTEP_TEXI2HTML_FLAGS),)
  GNUSTEP_TEXI2HTML_FLAGS = -split_chapter -expandinfo
endif

internal-doc-all_:: $(GNUSTEP_INSTANCE).info \
                    $(GNUSTEP_INSTANCE).pdf \
                    $(GNUSTEP_INSTANCE)_toc.html

internal-textdoc-all_:: $(GNUSTEP_INSTANCE)

# If we don't have these programs, just don't build them but don't
# abort the make. This allows projects to automatically build documentation
# without worring that the build will crash if the user doesn't have the
# doc programs. Also don't install them if they haven't been generated.

$(GNUSTEP_INSTANCE).info: $(TEXI_FILES)
	-$(GNUSTEP_MAKEINFO) $(GNUSTEP_MAKEINFO_FLAGS) $(ADDITIONAL_MAKEINFO_FLAGS) \
		-o $@ $(GNUSTEP_INSTANCE).texi

$(GNUSTEP_INSTANCE).dvi: $(TEXI_FILES)
	-$(GNUSTEP_TEXI2DVI) $(GNUSTEP_TEXI2DVI_FLAGS) $(ADDITIONAL_TEXI2DVI_FLAGS) \
	        $(GNUSTEP_INSTANCE).texi

$(GNUSTEP_INSTANCE).ps: $(GNUSTEP_INSTANCE).dvi
	-$(GNUSTEP_DVIPS) $(GNUSTEP_DVIPS_FLAGS) $(ADDITIONAL_DVIPS_FLAGS) \
		$(GNUSTEP_INSTANCE).dvi -o $@

$(GNUSTEP_INSTANCE).pdf: $(TEXI_FILES)
	-$(GNUSTEP_TEXI2PDF) $(GNUSTEP_TEXI2PDF_FLAGS) $(ADDITIONAL_TEXI2PDF_FLAGS) \
		$(GNUSTEP_INSTANCE).texi -o $@

$(GNUSTEP_INSTANCE)_toc.html: $(TEXI_FILES)
	-$(GNUSTEP_TEXI2HTML) $(GNUSTEP_TEXI2HTML_FLAGS) $(ADDITIONAL_TEXI2HTML_FLAGS) \
		$(GNUSTEP_INSTANCE).texi

$(GNUSTEP_INSTANCE): $(TEXI_FILES) $(TEXT_MAIN)
	-$(GNUSTEP_MAKETEXT) $(GNUSTEP_MAKETEXT_FLAGS) $(ADDITIONAL_MAKETEXT_FLAGS) \
		-o $@ $(TEXT_MAIN)

internal-doc-clean::
	-$(ECHO_NOTHING) rm -f $(GNUSTEP_INSTANCE).aux  \
	         $(GNUSTEP_INSTANCE).cp   \
	         $(GNUSTEP_INSTANCE).cps  \
	         $(GNUSTEP_INSTANCE).dvi  \
	         $(GNUSTEP_INSTANCE).fn   \
	         $(GNUSTEP_INSTANCE).info* \
	         $(GNUSTEP_INSTANCE).ky   \
	         $(GNUSTEP_INSTANCE).log  \
	         $(GNUSTEP_INSTANCE).pg   \
	         $(GNUSTEP_INSTANCE).ps   \
	         $(GNUSTEP_INSTANCE).pdf  \
	         $(GNUSTEP_INSTANCE).toc  \
	         $(GNUSTEP_INSTANCE).tp   \
	         $(GNUSTEP_INSTANCE).vr   \
	         $(GNUSTEP_INSTANCE).vrs  \
	         $(GNUSTEP_INSTANCE).html \
	         $(GNUSTEP_INSTANCE)_*.html \
	         $(GNUSTEP_INSTANCE).ps.gz  \
	         $(GNUSTEP_INSTANCE).tar.gz \
	         $(GNUSTEP_INSTANCE)/*$(END_ECHO)

# NB: Only install doc files if they have been generated

# We install all info files in the same directory, which is
# GNUSTEP_DOCUMENTATION_INFO.  TODO: I think we should run
# install-info too - to keep up-to-date the dir index in that
# directory.  
internal-doc-install_:: $(GNUSTEP_DOCUMENTATION_INFO)
	if [ -f $(GNUSTEP_INSTANCE).pdf ]; then \
	  $(INSTALL_DATA) $(GNUSTEP_INSTANCE).pdf \
	                $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR); \
	fi
	if [ -f $(GNUSTEP_INSTANCE).info ]; then \
	  $(INSTALL_DATA) $(GNUSTEP_INSTANCE).info* $(GNUSTEP_DOCUMENTATION_INFO); \
	fi
	if [ -f $(GNUSTEP_INSTANCE)_toc.html ]; then \
	  $(INSTALL_DATA) $(GNUSTEP_INSTANCE)_*.html \
	                  $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR); \
	fi
	if [ -f $(GNUSTEP_INSTANCE).html ]; then \
	  $(INSTALL_DATA) $(GNUSTEP_INSTANCE).html \
	                  $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR); \
	fi

$(GNUSTEP_DOCUMENTATION_INFO):
	$(ECHO_CREATING)$(MKINSTALLDIRS) $@$(END_ECHO)

internal-doc-uninstall_::
	rm -f \
          $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)/$(GNUSTEP_INSTANCE).pdf
	rm -f \
          $(GNUSTEP_DOCUMENTATION_INFO)/$(GNUSTEP_INSTANCE).info*
	rm -f \
          $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)/$(GNUSTEP_INSTANCE)_*.html
	rm -f \
          $(GNUSTEP_DOCUMENTATION)/$(DOC_INSTALL_DIR)/$(GNUSTEP_INSTANCE).html

