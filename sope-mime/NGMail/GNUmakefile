# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

ifneq ($(frameworks),yes)
SUBPROJECT_NAME = NGMail
else
FRAMEWORK_NAME = NGMail
endif

#NGMail_PCH_FILE = common.h
NGMail_HEADER_FILES_DIR         = .
NGMail_HEADER_FILES_INSTALL_DIR = /NGMail

NGMail_HEADER_FILES = \
	NGMailDecls.h		\
	NGMail.h		\
	NGMailAddressList.h     \
	NGMailAddressParser.h   \
	NGMailAddress.h         \
	NGMimeMessage.h		\
	NGMimeMessageGenerator.h\
	NGMimeMessageParser.h	\
	NGMBoxReader.h		\
	NGPop3Client.h		\
	NGPop3Support.h		\
	NGSmtpClient.h		\
	NGSmtpSupport.h		\
	NGSendMail.h		\

NGMail_OBJC_FILES = \
	NGMail.m		\
	NGMailAddressList.m     \
	NGMailAddressParser.m   \
	NGMailAddress.m         \
	NGMimeMessage.m		\
	NGMimeMessageGenerator.m\
	NGMimeMessageParser.m	\
	NGMBoxReader.m		\
	NGPop3Client.m		\
	NGPop3Support.m		\
	NGSmtpClient.m		\
	NGSmtpSupport.m		\
	NGSendMail.m		\
	\
	NGMimeMessageBodyGenerator.m		\
	NGMimeMessageMultipartBodyGenerator.m	\
	NGMimeMessageRfc822BodyGenerator.m	\
	NGMimeMessageTextBodyGenerator.m	\
	\
	NGMailBase64Encoding.m	\
	NSData+MimeQP.m		\

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/subproject.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
