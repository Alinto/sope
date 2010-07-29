# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

ifneq ($(frameworks),yes)
SUBPROJECT_NAME = NGImap4
else
FRAMEWORK_NAME = NGImap4
endif

#NGImap4_PCH_FILE = imCommon.h
NGImap4_HEADER_FILES_DIR         = .
NGImap4_HEADER_FILES_INSTALL_DIR = /NGImap4

NGImap4_HEADER_FILES = \
	NGImap4ResponseParser.h 	\
	NGImap4Client.h         	\
	NGImap4Support.h        	\
	NGImap4Folder.h         	\
	NGImap4Context.h		\
	NGImap4Message.h        	\
	NGImap4ServerRoot.h		\
	NGImap4FileManager.h		\
	NGImap4.h			\
	NGImap4DataSource.h		\
	NSString+Imap4.h		\
	NGSieveClient.h			\
	NGImap4Envelope.h		\
	NGImap4EnvelopeAddress.h	\
	NGImap4Connection.h		\
	NGImap4MailboxInfo.h		\
	NGImap4ConnectionManager.h	\

NGImap4_OBJC_FILES = \
	NGImap4ResponseParser.m 	\
	NGImap4Client.m         	\
	NGImap4Support.m        	\
	NGImap4.m			\
	NGImap4Folder.m         	\
	NGImap4Context.m		\
	NGImap4Message.m        	\
	NGImap4ServerRoot.m		\
	NGImap4Functions.m		\
	NGImap4FileManager.m		\
	NGImap4DataSource.m		\
	NSString+Imap4.m		\
	NGSieveClient.m			\
	EOQualifier+IMAPAdditions.m	\
	EOSortOrdering+IMAPAdditions.m	\
	\
	NGImap4MessageGlobalID.m	\
	NGImap4FolderGlobalID.m		\
	NGImap4ServerGlobalID.m		\
	NGImap4FolderMailRegistry.m	\
	NGImap4FolderFlags.m		\
	NGImap4ResponseNormalizer.m	\
	NGImap4Envelope.m		\
	NGImap4EnvelopeAddress.m	\
	\
	NGImap4Connection.m		\
	NGImap4MailboxInfo.m		\
	NGImap4ConnectionManager.m	\

include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/subproject.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
