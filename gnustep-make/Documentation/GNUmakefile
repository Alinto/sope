#
# This GNUmakefile needs to build the gnustep-make documentation.
#

# The GNUmakefile itself is written using gnustep-make.  If we find an
# existing gnustep-make installation, we use it.  Otherwise, we
# configure, compile and install gnustep-make into a temporary
# subdirectory, then we use that copy.

# In the very unlikely event that gnustep-make does not even install
# on your machine, please get a pre-generated copy of the
# documentation from the internet!  Or just read the documentation in
# source format. :-)

ifeq ($(GNUSTEP_MAKEFILES),)

# We have no gnustep-make installation to use.  We need gnustep-make
# to generate the documentation.

# To help lazy cows who want to type 'make' and have all work
# automatically without installating gnustep-make first, if we don't
# have a gnustep-make installation to use, we create a temporary one
# in the subdirectory ./tmp-installation, the run make again passing
# GNUSTEP_MAKEFILES set to point to the new makefile installation

# To execute all, or clean, or install, we first depend on a local
# temporary installation of gnustep-make; when we have it, we source
# GNUstep.sh, then we run the make command again.  Please note that
# "make install" will install into our temporary gnustep-make
# directory, which is usually not particularly useful, but anyway.
all clean install: ./tmp-installation/System/Library/Makefiles
	@echo "** Running 'make $@' using the local/temporary gnustep-make installation **"
	$(MAKE) $@ GNUSTEP_MAKEFILES="$(CURRENT_DIR)/tmp-installation/System/Library/Makefiles"

CURRENT_DIR = $(shell pwd)

# This creates a local temporary installation of GNUstep-make
./tmp-installation/System/Library/Makefiles:
	@echo "** No gnustep-make installation found, attempting to create a local/temporary one. **"
	(mkdir tmp-build; \
	cd tmp-build; \
	../../configure --prefix="$(CURRENT_DIR)/tmp-installation" \
	                --with-config-file="$(CURRENT_DIR)/tmp-installation/GNUstep.conf"; \
	make; \
	make install)

distclean:
	-(if [ -f ./tmp-installation/System/Library/Makefiles/common.make ]; then \
	  $(MAKE) $@ GNUSTEP_MAKEFILES="$(CURRENT_DIR)/tmp-installation/System/Library/Makefiles"; \
	fi)
	rm -Rf tmp-installation tmp-build

else

# We have a gnustep-make installation to use.  The following is a
# normal gnustep-make GNUmakefile for documentation.

# We normally install into System
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

# The documents to be generated
DOCUMENT_NAME = gnustep-howto faq filesystem internals machines make userfaq

# The text documents to be generated
DOCUMENT_TEXT_NAME = FAQ INSTALL README NEWS GNUstep-HOWTO ANNOUNCE

TOP_DOC_FILES = FAQ INSTALL README NEWS GNUstep-HOWTO ANNOUNCE
README_FILES = README.Darwin README.MinGWOnCygwin README.Cygwin \
	README.MinGW


GNUstep-HOWTO_TEXI_FILES = version.texi
GNUstep-HOWTO_TEXT_MAIN = gnustep-howto.texi
GNUstep-HOWTO_DOC_INSTALL_DIR = User/GNUstep/

FAQ_TEXI_FILES = version.texi
FAQ_TEXT_MAIN = faq.texi
FAQ_DOC_INSTALL_DIR = User/GNUstep/

make_TEXI_FILES = \
make.texi
make_DOC_INSTALL_DIR = Developer/Make/Manual/

faq_TEXI_FILES = \
faq.texi \
version.texi
faq_DOC_INSTALL_DIR = User/GNUstep/

userfaq_TEXI_FILES = \
userfaq.texi \
version.texi
userfaq_DOC_INSTALL_DIR = User/GNUstep/

filesystem_TEXI_FILES = \
filesystem.texi
filesystem_DOC_INSTALL_DIR = User/GNUstep/

machines_TEXI_FILES = \
machines.texi 
machines_DOC_INSTALL_DIR = User/GNUstep/

gnustep-howto_TEXI_FILES = \
gnustep-howto.texi \
version.texi
gnustep-howto_DOC_INSTALL_DIR = User/GNUstep/

internals_LATEX_FILES = \
internals.tex
internals_DOC_INSTALL_DIR = Developer/Make/Manual/Internals/

INSTALL_TEXI_FILES = version.texi
INSTALL_TEXT_MAIN = install.texi
INSTALL_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

NEWS_TEXI_FILES = version.texi
NEWS_TEXT_MAIN = news.texi
NEWS_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

README_TEXI_FILES = version.texi
README_TEXT_MAIN = readme.texi
README_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

ANNOUNCE_TEXI_FILES = version.texi
ANNOUNCE_TEXT_MAIN = announce.texi
ANNOUNCE_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

# Manual pages to install
MAN1_PAGES = openapp.1
MAN7_PAGES = GNUstep.7

include $(GNUSTEP_MAKEFILES)/documentation.make

include ../Version

GNUSTEP_TEXI2HTML_FLAGS += -init_file gnustep.init

# Typing 'make regenerate' should build all, then install the files
# top-level.  This is mostly for making gnustep-make releases.
regenerate: all
	mv -f $(TOP_DOC_FILES) ..

# Generate the version.texi file from the Version of gnustep-make.
version.texi: ../Version
	rm -f version.texi
	echo '@set GNUSTEP-MAKE-VERSION' $(GNUSTEP_MAKE_VERSION) \
	 > version.texi

# Install manually man pages
after-install:: $(GNUSTEP_DOCUMENTATION)/Developer/Make/Manual $(GNUSTEP_DOCUMENTATION)/User/GNUstep
	$(INSTALL_DATA) DESIGN $(GNUSTEP_DOCUMENTATION)/Developer/Make/Manual
	for file in $(README_FILES); do \
	  $(INSTALL_DATA) $$file $(GNUSTEP_DOCUMENTATION)/User/GNUstep/$$file; \
	done;
	if [ ! -f $(GNUSTEP_DOCUMENTATION_MAN) ]; then \
	  $(MKDIRS) $(GNUSTEP_DOCUMENTATION_MAN); \
	fi; \
	if [ ! -f $(GNUSTEP_DOCUMENTATION_MAN)/man1 ]; then \
	  $(MKDIRS) $(GNUSTEP_DOCUMENTATION_MAN)/man1; \
	fi; \
	for file in $(MAN1_PAGES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $$file $(GNUSTEP_DOCUMENTATION_MAN)/man1/$$file; \
	    which gzip && rm -f $(GNUSTEP_DOCUMENTATION_MAN)/man1/$$file.gz \
		&& gzip -9 $(GNUSTEP_DOCUMENTATION_MAN)/man1/$$file; \
	  fi; \
	done;
	if [ ! -f $(GNUSTEP_DOCUMENTATION_MAN)/man7 ]; then \
	  $(MKDIRS) $(GNUSTEP_DOCUMENTATION_MAN)/man7; \
	fi; \
	for file in $(MAN7_PAGES) __done; do \
	  if [ $$file != __done ]; then \
	    $(INSTALL_DATA) $$file $(GNUSTEP_DOCUMENTATION_MAN)/man7/$$file; \
	    which gzip && rm -f $(GNUSTEP_DOCUMENTATION_MAN)/man7/$$file.gz \
		&& gzip -9 $(GNUSTEP_DOCUMENTATION_MAN)/man7/$$file; \
	  fi; \
	done;

#  Uninstall manually man pages
after-uninstall::
	rm -f $(GNUSTEP_DOCUMENTATION)/Developer/Make/Manual/DESIGN
	for file in $(MAN1_PAGES) __done; do \
	  if [ $$file != __done ]; then \
	    rm -f $(GNUSTEP_DOCUMENTATION_MAN)/man1/$$file; \
	  fi; \
	done;
	for file in $(MAN7_PAGES) __done; do \
	  if [ $$file != __done ]; then \
	    rm -f $(GNUSTEP_DOCUMENTATION_MAN)/man7/$$file; \
	  fi; \
	done;

after-distclean::
	rm -f version.texi
endif
