# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../../Version
include ../Version

BUNDLE_NAME        = XUL
BUNDLE_EXTENSION   = .odr
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/Bundles

XUL_OBJC_FILES = \
	ODXULNodeRenderFactory.m\
	ODRDynamicXULTag.m		\
	ODR_XUL_box.m			\
	ODR_XUL_button.m		\
	ODR_XUL_title.m			\
	ODR_XUL_titledbox.m		\
	ODR_XUL_spring.m		\
	ODR_XUL_text.m			\
	ODR_XUL_textfield.m		\
	ODR_XUL_window.m		\
	ODR_XUL_image.m			\

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
