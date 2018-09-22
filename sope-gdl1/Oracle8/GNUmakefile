#
#  GNUmakefile
#
#  Copyright (c) 2007  Inverse groupe conseil inc. and Ludovic Marcotte
#
#  Author: Ludovic Marcotte <ludovic@inverse.ca>
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

# Global properties and dependancies
SOPE_ROOT=../..
ORACLE_VERSION=$(shell echo /usr/include/oracle/* | awk '{ print $$NF }' | awk -F / '{ print $$NF }')
#ORACLE_VERSION=10.2.0.3
#ORACLE_VERSION=11.1.0.1
ADDITIONAL_INCLUDE_DIRS += -I../../sope-core -I../../sope-core/NGExtensions -I../GDLAccess -I.. -I/usr/include/oracle/$(ORACLE_VERSION)/client64 -I/usr/include/oracle/$(ORACLE_VERSION)/client

local_arch = $(subst 64,,$(shell uname -m))

ifeq ($(local_arch),ppc)
PPC_LDFLAGS=-L/opt/ibmcmp/lib -libmc++
else
PPC_LDFLAGS=
endif

ifneq ($(frameworks),yes)
common_LIBS = -L/usr/lib/oracle/$(ORACLE_VERSION)/client64/lib/ -L/usr/lib/oracle/$(ORACLE_VERSION)/client/lib/ -locci -lociei -lclntsh -lnnz11 -L../GDLAccess/obj -lGDLAccess -L../../sope-core/EOControl/obj -lEOControl $(PPC_LDFLAGS)
else
common_LIBS = -L/usr/lib/oracle/$(ORACLE_VERSION)/client64/lib/ -L/usr/lib/oracle/$(ORACLE_VERSION)/client/lib/ -locci -lociei -lclntsh -lnnz11 -framework GDLAccess -framework EOControl $(PPC_LDFLAGS)
endif
Oracle8_BUNDLE_LIBS += $(common_LIBS)
otest_TOOL_LIBS   += $(common_LIBS)

# Bundle
BUNDLE_NAME = Oracle8
ifeq ($(frameworks),yes)
BUNDLE_INSTALL_DIR := $(FRAMEWORK_INSTALL_DIR)/GDLAccess.framework/Resources/GDLAdaptors/
else
BUNDLE_INSTALL_DIR = $(SOPE_DBADAPTORS)/
endif

Oracle8_OBJC_FILES = \
	EOAttribute+Oracle.m \
	OracleAdaptor.m \
	OracleAdaptorChannel.m \
	OracleAdaptorChannelController.m \
	OracleAdaptorContext.m \
	OracleSQLExpression.m \
	OracleValues.m \
	err.m

Oracle8_PRINCIPAL_CLASS = OracleAdaptor

BUNDLE_INSTALL = Oracle8
BUNDLE_EXTENSION = .gdladaptor
Oracle8_RESOURCE_FILES += Version

# Tool
TOOL_NAME = otest
otest_OBJC_FILES = otest.m

include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/tool.make
