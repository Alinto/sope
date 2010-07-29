# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = \
	meerkat_xml_channels	\
	blogger_zidestore

meerkat_xml_channels_OBJC_FILES += meerkat_xml_channels.m

blogger_zidestore_OBJC_FILES += blogger_zidestore.m NGBloggerClient.m

ADDITIONAL_TOOL_LIBS += \
	-lNGXmlRpc -lNGObjWeb -lNGMime -lNGStreams -lNGExtensions -lEOControl \
	-lXmlRpc -lDOM -lSaxObjC

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
