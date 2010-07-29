# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../../Version
include ../Version

SUBPROJECT_NAME = Dynamic

ADDITIONAL_CPPFLAGS += -pipe -Wall

Dynamic_OBJC_FILES = \
	ODBindNodeRenderFactory.m	\
	ODR_bind_checkbox.m		\
	ODR_bind_collapsible.m		\
	ODR_bind_datefield.m		\
	ODR_bind_fieldset.m		\
	ODR_bind_foreach.m		\
	ODR_bind_form.m			\
	ODR_bind_groupings.m		\
	ODR_bind_if.m			\
	ODR_bind_multiselection.m	\
	ODR_bind_nbsp.m			\
	ODR_bind_popupbutton.m		\
	ODR_bind_radiobutton.m		\
	ODR_bind_sortorderings.m	\
	ODR_bind_string.m		\
	ODR_bind_switch.m		\
	ODR_bind_tablecell.m            \
	ODR_bind_tabledata.m            \
	ODR_bind_tableheader.m          \
	ODR_bind_tableview+Private.m	\
	ODR_bind_tableview.m		\
	ODR_bind_tabview.m		\
	ODR_bind_viewertitle.m		\
	ODR_bind_with.m			\

ADDITIONAL_INCLUDE_DIRS += \
	-I..			\
	-I../..			\
	-I../../NGObjWeb	\
	-I../../NGStreams	\

ifeq ($(FOUNDATION_LIB),nx)

ADDITIONAL_LIB_DIRS += 				\
	-L../$(GNUSTEP_OBJ_DIR)			\
	-L../../NGObjWeb/$(GNUSTEP_OBJ_DIR)	\

XUL_BUNDLE_LIBS += \
	-lNGObjDOM	\
	-lNGMime	\
	-lNGStreams	\
	-lEOControl	\
	-lNGExtensions	\
	-lFoundationExt	\

ADDITIONAL_LDFLAGS += -framework Foundation

endif

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
