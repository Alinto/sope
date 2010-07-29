# GNUstep makefile

include ../../../config.make
include ../../Version
include ../Version
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = WebDAV

WebDAV_PCH_FILE = common.h
WebDAV_HEADER_FILES_DIR         = .
WebDAV_HEADER_FILES_INSTALL_DIR = /NGObjWeb

WebDAV_HEADER_FILES = \
	SoDAV.h				\
	EOFetchSpecification+SoDAV.h	\
	SaxDAVHandler.h			\
	SoDAVLockManager.h		\
	SoObject+SoDAV.h		\
	SoObjectDataSource.h		\
	SoObjectResultEntry.h		\
	SoObjectWebDAVDispatcher.h	\
	SoWebDAVRenderer.h		\
	SoWebDAVValue.h			\
	SoSubscriptionManager.h		\
	SoSubscription.h		\
	SoDAVSQLParser.h		\

WebDAV_OBJC_FILES = \
	EOFetchSpecification+SoDAV.m	\
	SaxDAVHandler.m			\
	SoDAVLockManager.m		\
	SoObject+SoDAV.m		\
	SoObject+SoDAVQuery.m		\
	SoObjectDataSource.m		\
	SoObjectWebDAVDispatcher.m	\
	SoWebDAVRenderer.m		\
	SoWebDAVValue.m			\
	SoObjectResultEntry.m		\
	SoSubscriptionManager.m		\
	SoSubscription.m		\
	SoDAVSQLParser.m		\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
