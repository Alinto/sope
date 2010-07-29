# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=sope-xml
VERSION=4.5.0

SUBPROJECTS = \
	SaxObjC		\
	DOM		\
	XmlRpc

SUBPROJECTS += STXSaxDriver

ifneq ($(HAS_LIBRARY_xml2),no)
SUBPROJECTS += libxmlSAXDriver
endif


ifeq ($(frameworks),yes)
include umbrella.make
endif

# project makefiles

include $(GNUSTEP_MAKEFILES)/aggregate.make
ifeq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/framework.make
endif


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh sope-xml
