# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
include ./Version

#ADDITIONAL_CPPFLAGS += -DTRACK_JSMEM=1 -DTRACK_JSMEM_RC=1

LIBRARY_NAME = libNGScripting

libNGScripting_HEADER_FILES_DIR         = .
libNGScripting_HEADER_FILES_INSTALL_DIR = /NGScripting
FHS_HEADER_FILES_INSTALL_DIR = $(libNGScripting_HEADER_FILES_INSTALL_DIR)
libNGScripting_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGScripting_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGScripting_HEADER_FILES = \
	NSObject+Scripting.h			\
	NGObjectMappingContext.h		\
	NGScriptLanguage.h			\

libNGScripting_OBJC_FILES = \
	NSObject+Scripting.m		\
	NGObjectMappingContext.m	\
	NGScriptLanguage.m		\

autodoc :
	autodoc $(AUTODOC_FLAGS) -dest $(AUTODOC_DESTPATH)/NGScripting/ -proj .

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
include fhs.make
