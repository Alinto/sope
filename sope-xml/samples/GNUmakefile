# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = \
	saxxml		\
	xmln		\
	rss2plist1	\
	rss2plist2	\
	rssparse	\
	domxml		\
	testqp		\

rss2plist1_OBJC_FILES = rss2plist1.m
rss2plist2_OBJC_FILES = rss2plist2.m
rssparse_OBJC_FILES   = rssparse.m
saxxml_OBJC_FILES     = saxxml.m
xmln_OBJC_FILES       = xmln.m
domxml_OBJC_FILES     = domxml.m
testqp_OBJC_FILES     = testqp.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make
