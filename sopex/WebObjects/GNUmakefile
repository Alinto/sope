# WebObjects.framework
# GNUmakefile
#
# $Id: GNUmakefile 1 2004-08-20 11:17:52Z znek $


# Install into the local root by default
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_LOCAL_ROOT)

include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = WebObjects

VERSION = 4.5.1

WebObjects_HEADER_FILES_DIR = .

WebObjects_HEADER_FILES_INSTALL_DIR = /WebObjects

WebObjects_HEADER_FILES = WebObjects.h

WebObjects_C_FILES = main.c

WebObjects_LIBRARIES_DEPEND_UPON = -lNGObjWeb

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
