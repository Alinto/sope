# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = NGHttp

NGHttp_PCH_FILE = common.h
NGHttp_HEADER_FILES_DIR         = .
NGHttp_HEADER_FILES_INSTALL_DIR = /NGHttp

NGHttp_HEADER_FILES = \
	NGHttpDecls.h			\
	NGHttp.h			\
	NGHttpCookie.h			\
	NGHttpHeaderFieldParser.h	\
	NGHttpHeaderFields.h		\
	NGHttpBodyParser.h		\
	NGHttpMessage.h			\
	NGHttpMessageParser.h		\
	NGHttpRequest.h			\
	NGHttpResponse.h		\
	NGUrlFormCoder.h		\

NGHttp_OBJC_FILES = \
	NGHttp.m			\
	NGHttpCookie.m			\
	NGHttpHeaderFieldParser.m	\
	NGHttpHeaderFields.m		\
	NGHttpBodyParser.m		\
	NGHttpMessage.m			\
	NGHttpMessageParser.m		\
	NGHttpRequest.m			\
	NGHttpResponse.m		\
	NGUrlFormCoder.m		\

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
