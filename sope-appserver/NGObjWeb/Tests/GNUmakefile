# GNUstep makefile

include $(GNUSTEP_MAKEFILES)/common.make

TEST_TOOL = ngobjweb-tests
$(TEST_TOOL)_OBJC_FILES = \
	TestWOHttpContentLength.m

TEST_TOOL_NAME = $(TEST_TOOL)

$(TEST_TOOL)_CPPFLAGS += \
	-Wall -D_GNU_SOURCE -I.. -I.. -I../../..

ADDITIONAL_LIB_DIRS += \
	-L../../NGObjWeb/obj -L../../../sope-core/NGStreams/obj \
	-L../../../sope-core/NGExtensions/obj \
	-lNGObjWeb -lNGStreams -lNGExtensions -lEOControl \
	-Wl,-rpath,../../NGObjWeb/obj -Wl,-rpath,../../../sope-core/NGStreams/obj

include $(GNUSTEP_MAKEFILES)/test-tool.make

check :: $(TEST_TOOL)
	LD_LIBRARY_PATH=$(CURDIR)/../../NGObjWeb/obj:$(CURDIR)/../../../sope-core/NGStreams/obj:$(CURDIR)/../../../sope-core/NGExtensions/obj:$(LD_LIBRARY_PATH) \
	  ./obj/$(TEST_TOOL)
