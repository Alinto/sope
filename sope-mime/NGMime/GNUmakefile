# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

SUBPROJECT_NAME = NGMime

#NGMime_PCH_FILE = common.h
NGMime_HEADER_FILES_DIR         = .
NGMime_HEADER_FILES_INSTALL_DIR = /NGMime

NGMime_HEADER_FILES = \
	NGMimeDecls.h			\
	NGMime.h			\
	\
	NGConcreteMimeType.h		\
	NGMimeBodyGenerator.h		\
	NGMimeBodyParser.h		\
	NGMimeBodyPart.h		\
	NGMimeBodyPartParser.h		\
	NGMimeExceptions.h        	\
	NGMimeGeneratorProtocols.h	\
	NGMimeHeaderFieldGenerator.h	\
	NGMimeHeaderFieldParser.h 	\
	NGMimeHeaderFields.h		\
	NGMimeMultipartBody.h		\
	NGMimePartGenerator.h		\
	NGMimePartParser.h        	\
	NGMimeType.h			\
	NGMimeUtilities.h		\
	NGPart.h			\
	NGMimeFileData.h		\
	NGMimeJoinedData.h		\

NGMime_OBJC_FILES = \
	NGMime.m			\
	\
	NGConcreteMimeType.m		\
	NGMimeBodyGenerator.m		\
	NGMimeBodyParser.m		\
	NGMimeBodyPart.m		\
	NGMimeBodyPartParser.m		\
	NGMimeExceptions.m        	\
	NGMimeHeaderFieldGenerator.m	\
	NGMimeHeaderFieldParser.m 	\
	NGMimeHeaderFields.m		\
	NGMimeMultipartBody.m		\
	NGMimeMultipartBodyParser.m	\
	NGMimePartGenerator.m		\
	NGMimePartParser.m        	\
	NGMimeType.m			\
	NGPart.m			\
	NGMimeFileData.m		\
	NGMimeJoinedData.m		\
	NGMimeUtilities.m		\
	\
	NGMimeContentDispositionHeaderFieldParser.m	\
	NGMimeContentLengthHeaderFieldParser.m		\
	NGMimeContentTypeHeaderFieldParser.m		\
	NGMimeHeaderFieldParserSet.m			\
	NGMimeRFC822DateHeaderFieldParser.m		\
	NGMimeStringHeaderFieldParser.m			\
	NSCalendarDate+RFC822.m				\
	\
	NGMimeAddressHeaderFieldGenerator.m		\
	NGMimeContentDispositionHeaderFieldGenerator.m	\
	NGMimeContentLengthHeaderFieldGenerator.m	\
	NGMimeContentTypeHeaderFieldGenerator.m		\
	NGMimeHeaderFieldGeneratorSet.m			\
	NGMimeRFC822DateHeaderFieldGenerator.m		\
	NGMimeStringHeaderFieldGenerator.m		\
	\
	NGMimeMultipartBodyGenerator.m			\
	NGMimeTextBodyGenerator.m			\
	NGMimeRfc822BodyGenerator.m			\

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
