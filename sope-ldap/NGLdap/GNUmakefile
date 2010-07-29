# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGLdap
else
FRAMEWORK_NAME = NGLdap
endif

libNGLdap_PCH_FILE = common.h
libNGLdap_HEADER_FILES_DIR         = .
libNGLdap_HEADER_FILES_INSTALL_DIR = /NGLdap
libNGLdap_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGLdap_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libNGLdap_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGLdap_HEADER_FILES = \
	NGLdap.h			\
	\
	EOQualifier+LDAP.h		\
	NSString+DN.h			\
	NGLdapEntry.h			\
	NGLdapConnection.h		\
	NGLdapAttribute.h		\
	NGLdapModification.h		\
	NGLdapSearchResultEnumerator.h	\
	\
	NGLdapURL.h			\
	NGLdapGlobalID.h		\
	NGLdapFileManager.h		\
	NGLdapDataSource.h		\

libNGLdap_CORE_OBJC_FILES = \
	EOQualifier+LDAP.m		\
	NSString+DN.m			\
	NGLdapAttribute.m		\
	NGLdapEntry.m			\
	NGLdapSearchResultEnumerator.m	\
	NGLdapModification.m		\
	NGLdapConnection.m		\
	NGLdapDataSource.m		\

libNGLdap_OBJC_FILES = \
	$(libNGLdap_CORE_OBJC_FILES)	\
	NGLdapURL.m			\
	NGLdapGlobalID.m		\
	NGLdapFileManager.m		\


# framework support

NGLdap_PCH_FILE     = $(libNGLdap_PCH_FILE)
NGLdap_HEADER_FILES = $(libNGLdap_HEADER_FILES)
NGLdap_OBJC_FILES   = $(libNGLdap_OBJC_FILES)


# building

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
