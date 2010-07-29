# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = \
	encoding	\
	fmdls		\
	testdirenum	\
	bmlookup	\
	eoqual		\
	testsock	\
	httpu_notify	\
	parserule	\
	testurl		\
	sope-rsrclookup	\
	ngcal

ifneq ($(OBJC_RUNTIME_LIB),apple)
TOOL_NAME += subclassing
endif

encoding_OBJC_FILES      = EncodingTool.m encoding.m
subclassing_OBJC_FILES   = subclassing.m
fmdls_OBJC_FILES         = fmdls.m
bmlookup_OBJC_FILES      = bmlookup.m
testdirenum_OBJC_FILES   = testdirenum.m
eoqual_OBJC_FILES        = eoqual.m EOQualTool.m
testsock_OBJC_FILES      = testsock.m
parserule_OBJC_FILES     = parserule.m
httpu_notify_OBJC_FILES  = httpu_notify.m
testurl_OBJC_FILES       = testurl.m
sope-rsrclookup_OBJC_FILES = sope-rsrclookup.m
ngcal_OBJC_FILES         = ngcal.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make
