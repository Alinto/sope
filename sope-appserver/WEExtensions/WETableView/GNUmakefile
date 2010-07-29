# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = WETableView

WETableView_PCH_FILE = common.h

WETableView_OBJC_FILES = \
	WETableCell.m		\
	WETableData.m		\
	WETableHeader.m		\
	WETableView.m		\
	WETableView+Grouping.m	\
	\
	WETableViewState.m		\
	WETableViewConfigObject.m	\
	WETableViewColorConfig.m	\
	WETableViewIconConfig.m		\
	WETableViewLabelConfig.m	\
	\
	WETableViewButtonMode.m	\
	WETableViewFooterMode.m	\
	WETableViewGroupMode.m	\
	WETableViewTitleMode.m	\

ADDITIONAL_INCLUDE_DIRS += -I. -I.. -I../.. -I../../NGObjWeb

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
