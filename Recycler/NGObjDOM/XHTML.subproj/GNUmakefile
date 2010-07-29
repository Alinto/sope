# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../../Version
include ../Version

BUNDLE_NAME        = XHTML
BUNDLE_EXTENSION   = .odr
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/Bundles

XHTML_OBJC_FILES = \
	ODRDynamicXHTMLTag.m		\
	ODXHTMLNodeRenderFactory.m	\
	\
	ODR_XHTML_a.m		\
	ODR_XHTML_button.m	\
	ODR_XHTML_form.m	\
	ODR_XHTML_img.m		\
	ODR_XHTML_input.m	\
	ODR_XHTML_option.m	\
	ODR_XHTML_select.m	\
	ODR_XHTML_textarea.m	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

ifneq ($(GNUSTEP_BUILD_DIR),)
after-all ::
	@(cp bundle-info.plist \
	  $(GNUSTEP_BUILD_DIR)/$(BUNDLE_NAME)$(BUNDLE_EXTENSION))
else
after-all ::
	@(cd $(BUNDLE_NAME)$(BUNDLE_EXTENSION);\
	  cp ../bundle-info.plist .)
endif
