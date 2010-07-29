# GNUstep makefile

include ../../config.make
include ../common.make
include ./Version

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGStreams
else
FRAMEWORK_NAME = NGStreams
endif

libNGStreams_PCH_FILE                 = common.h
libNGStreams_DLL_DEF                  = libNGStreams.def
libNGStreams_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGStreams_INSTALL_DIR=$(SOPE_SYSLIBDIR)
libNGStreams_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGStreams_HEADER_FILES_DIR         = NGStreams
libNGStreams_HEADER_FILES_INSTALL_DIR = /NGStreams

libNGStreams_HEADER_FILES = \
	NGStreamsDecls.h		\
	NGStreams.h 			\
	NGStreamProtocols.h		\
	NGTextStreamProtocols.h		\
	NGBase64Stream.h		\
	NGBufferedStream.h		\
	NGByteCountStream.h		\
	NGCTextStream.h			\
	NGConcreteStreamFileHandle.h 	\
	NGDataStream.h			\
	NGFileStream.h			\
	NGFilterStream.h		\
	NGFilterTextStream.h		\
	NGLockingStream.h		\
	NGStream.h			\
	NGStreamExceptions.h		\
	NGStringTextStream.h		\
	NGTextStream.h			\
	NGDescriptorFunctions.h		\
	NGStreamPipe.h			\
	NGByteBuffer.h			\
	NGCharBuffer.h			\
	NGTerminalSupport.h		\
	\
	NGActiveSocket.h		\
	NGDatagramPacket.h		\
	NGDatagramSocket.h		\
	NGInternetSocketAddress.h	\
	NGInternetSocketDomain.h	\
	NGLocalSocketAddress.h		\
	NGLocalSocketDomain.h		\
	NGNet.h				\
	NGNetDecls.h			\
	NGNetUtilities.h		\
	NGPassiveSocket.h		\
	NGSocket.h			\
	NGSocketExceptions.h		\
	NGSocketProtocols.h		\
	\
	NGGZipStream.h			\

libNGStreams_OBJC_FILES = \
	NGStreams.m			\
	NGBase64Stream.m		\
	NGBufferedStream.m		\
	NGByteCountStream.m		\
	NGCTextStream.m			\
	NGConcreteStreamFileHandle.m	\
	NGDataStream.m			\
	NGFileStream.m			\
	NGFilterStream.m		\
	NGFilterTextStream.m		\
	NGLockingStream.m		\
	NGStream.m			\
	NGStreamExceptions.m		\
	NGStringTextStream.m		\
	NGTextStream.m			\
	NGDescriptorFunctions.m		\
	NGStreamPipe.m			\
	NGByteBuffer.m			\
	NGCharBuffer.m			\
	NGTerminalSupport.m		\
	\
	NGActiveSocket.m		\
	NGDatagramPacket.m		\
	NGDatagramSocket.m		\
	NGInternetSocketAddress.m	\
	NGInternetSocketDomain.m	\
	NGLocalSocketAddress.m		\
	NGLocalSocketDomain.m		\
	NGNetUtilities.m		\
	NGPassiveSocket.m		\
	NGSocket.m			\
	NGSocketExceptions.m		\
	\
	NGGZipStream.m			\

# framework support
NGStreams_PCH_FILE         = $(libNGStreams_PCH_FILE)
NGStreams_HEADER_FILES_DIR = $(libNGStreams_HEADER_FILES_DIR)
NGStreams_HEADER_FILES     = $(libNGStreams_HEADER_FILES)
NGStreams_OBJC_FILES       = $(libNGStreams_OBJC_FILES)


# building

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
ifneq ($(frameworks),yes)
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include GNUmakefile.postamble
