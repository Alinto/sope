# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = icalparsetest icalds vcf2xml vcfparsetest ievalrrule

icalparsetest_OBJC_FILES = icalparsetest.m
icalds_OBJC_FILES        = icalds.m
vcf2xml_OBJC_FILES       = vcf2xml.m
vcfparsetest_OBJC_FILES  = vcfparsetest.m
ievalrrule_OBJC_FILES    = ievalrrule.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make
