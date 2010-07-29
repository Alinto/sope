# $Id$

include ../common.make

#ADDITIONAL_CPPFLAGS += -DTRACK_JSMEM=1 -DTRACK_JSMEM_RC=1

LIBRARY_NAME       = libNGJavaScript
BUNDLE_NAME        = SpiderMonkey
BUNDLE_EXTENSION   := .sse
 # SKYRiX script engine ;-)
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/ScriptEngines

# NGJavaScript

libNGJavaScript_SUBPROJECTS = Core+JS.subproj
libNGJavaScript_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

libNGJavaScript_HEADER_FILES = \
	NGJavaScriptDecls.h			\
	NGJavaScript.h				\
	\
	NGJavaScriptObject.h			\
	NGJavaScriptContext.h			\
	NGJavaScriptFunction.h			\
	NGJavaScriptCallable.h			\
	NGJavaScriptObjectHandler.h		\
	NGJavaScriptRuntime.h			\
	NGJavaScriptObjectMappingContext.h	\
	NGJavaScriptShadow.h			\
	NGJavaScriptError.h			\

libNGJavaScript_OBJC_FILES = globals.m \
	NGJavaScriptArray.m			\
	NGJavaScriptContext.m			\
	NGJavaScriptFunction.m			\
	NGJavaScriptObjCClassInfo.m		\
	NGJavaScriptObject.m			\
	NGJavaScriptCallable.m			\
	NGJavaScriptObjectHandler.m		\
	NGJavaScriptRuntime.m			\
	NGJavaScriptShadow.m			\
	NGJavaScriptObjectMappingContext.m	\
	NGJavaScriptLanguage.m			\
	NGJavaScriptError.m			\

SpiderMonkey_OBJC_FILES =  dummy.m
SpiderMonkey_BUNDLE_LIBS += -lNGJavaScript
SpiderMonkey_RESOURCE_FILES += ScriptLanguages.plist

libNGJavaScript_HEADER_FILES_DIR         = .
libNGJavaScript_HEADER_FILES_INSTALL_DIR = /NGJavaScript

ADDITIONAL_INCLUDE_DIRS += -I.. -I./Core+JS.subproj

libNGJavaScript_LIBRARIES_DEPEND_UPON += -lNGScripting

ifneq ($(GNUSTEP_BUILD_DIR),)
libNGJavaScript_LIB_DIRS += \
	-L$(GNUSTEP_BUILD_DIR)/../NGScripting/$(GNUSTEP_OBJ_DIR_NAME)
else
libNGJavaScript_LIB_DIRS += -L../NGScripting/$(GNUSTEP_OBJ_DIR)
endif

#	-I../js/$(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)\

# test tool

TOOL_NAME = testjs # jsobjops

testjs_OBJC_FILES   += testjs.m $(libNGJavaScript_OBJC_FILES)
testjs_SUBPROJECTS  = tests

jsobjops_OBJC_FILES += jsobjops.m $(libNGJavaScript_OBJC_FILES)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make

ifeq ($(tests),yes)
  include $(GNUSTEP_MAKEFILES)/tool.make
endif

-include GNUmakefile.postamble

autodoc :
	autodoc $(AUTODOC_FLAGS) -dest $(AUTODOC_DESTPATH)/NGJavaScript/ -proj .
