# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = \
	mime2xml	\
	imapls		\
	test_qpdecode	\
	imapquota	\
	imapacl		\
	imap_tool	\
	sievetool	\
	imapcontest	\

imapquota_OBJC_FILES     = ImapQuotaTool.m ImapTool.m imapquota.m
imapacl_OBJC_FILES       = ImapQuotaTool.m ImapTool.m imapacl.m
imapget_OBJC_FILES       = ImapTool.m imapget.m
imap_tool_OBJC_FILES     = imap_tool.m
mime2xml_OBJC_FILES      = Mime2XmlTool.m mime2xml.m
imapls_OBJC_FILES        = ImapTool.m ImapListTool.m imapls.m
test_qpdecode_OBJC_FILES = test_qpdecode.m
sievetool_OBJC_FILES	 = sievetool.m
imapcontest_OBJC_FILES	 = imapcontest.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make
