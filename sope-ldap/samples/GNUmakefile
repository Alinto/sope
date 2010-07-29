# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = \
	ldapls		\
	ldap2dsml	\
	ldapchkpwd	\

ldapls_OBJC_FILES	 = ldapls.m
ldapls_INSTALL_DIR	 = $(SOPE_TOOLS)/
ldap2dsml_OBJC_FILES	 = ldap2dsml.m
ldap2dsml_INSTALL_DIR	 = $(SOPE_TOOLS)/
ldapchkpwd_OBJC_FILES	 = ldapchkpwd.m
ldapchkpwd_INSTALL_DIR	 = $(SOPE_TOOLS)/

#TOOL_NAME = #pwd-check
#pwd-check_OBJC_FILES = pwd-check.m


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
