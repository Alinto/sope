# GNUstep makefile

include ../../config.make
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
imapquota_INSTALL_DIR	 = $(SOPE_TOOLS)
imapacl_OBJC_FILES       = ImapQuotaTool.m ImapTool.m imapacl.m
imapctl_INSTALL_DIR	 = $(SOPE_TOOLS)
imapget_OBJC_FILES       = ImapTool.m imapget.m
imapget_INSTALL_DIR	 = $(SOPE_TOOLS)
imap_tool_OBJC_FILES     = imap_tool.m
imap_tool_INSTALL_DIR	 = $(SOPE_TOOLS)
mime2xml_OBJC_FILES      = Mime2XmlTool.m mime2xml.m
mime2xml_INSTALL_DIR	 = $(SOPE_TOOLS)
imapls_OBJC_FILES        = ImapTool.m ImapListTool.m imapls.m
imapls_INSTALL_DIR	 = $(SOPE_TOOLS)
test_qpdecode_OBJC_FILES = test_qpdecode.m
test_qpdecode_INSTALL_DIR= $(SOPE_TOOLS)
sievetool_OBJC_FILES	 = sievetool.m
sievetool_INSTALL_DIR	 = $(SOPE_TOOLS)
imapcontest_OBJC_FILES	 = imapcontest.m
imapcontest_INSTALL_DIR	 = $(SOPE_TOOLS)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
