# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=sope-ldap
VERSION=4.5.0

SUBPROJECTS = \
	NGLdap

include $(GNUSTEP_MAKEFILES)/aggregate.make


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh sope-ldap
