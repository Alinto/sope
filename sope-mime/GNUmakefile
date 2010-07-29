# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGMime
else
FRAMEWORK_NAME = NGMime
endif

libNGMime_HEADER_FILES_DIR         = .
libNGMime_HEADER_FILES_INSTALL_DIR = /NGMime
libNGMime_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGMime_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libNGMime_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

ifneq ($(frameworks),yes)
libNGMime_SUBPROJECTS = NGMime NGMail NGImap4
else
libNGMime_SUBPROJECTS = NGMime
SUBPROJECTS = NGMail NGImap4
endif


# framework support

NGMime_HEADER_FILES = $(libNGMime_HEADER_FILES)
NGMime_OBJC_FILES   = $(libNGMime_OBJC_FILES)
NGMime_SUBPROJECTS  = $(libNGMime_SUBPROJECTS)


# building

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
endif
-include GNUmakefile.postamble


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh sope-mime
