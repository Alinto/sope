# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME=sope-gdl1
VERSION=4.7.0

SUBPROJECTS += GDLAccess

ifeq ($(HAS_LIBRARY_pq),yes)
SUBPROJECTS += PostgreSQL
endif

ifeq ($(HAS_LIBRARY_sqlite3),yes)
SUBPROJECTS += SQLite3
endif

ifeq ($(HAS_LIBRARY_mysqlclient),yes)
SUBPROJECTS += MySQL
endif

ifeq ($(HAS_LIBRARY_oracle),yes)
SUBPROJECTS += Oracle
endif

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble


# package

macosx-pkg :: all
	../maintenance/make-osxpkg.sh sope-gdl1
