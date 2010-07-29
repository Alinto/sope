# 
#  GNUmakefile.gnustep
#
#  Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
#  All rights reserved.
#
#  Author: Ovidiu Predescu <ovidiu@net-community.com>
#  Date: September 1997
#
#  This file is part of libFoundation.
#
#  Permission to use, copy, modify, and distribute this software and its
#  documentation for any purpose and without fee is hereby granted, provided
#  that the above copyright notice appear in all copies and that both that
#  copyright notice and this permission notice appear in supporting
#  documentation.
#
#  We disclaim all warranties with regard to this software, including all
#  implied warranties of merchantability and fitness, in no event shall
#  we be liable for any special, indirect or consequential damages or any
#  damages whatsoever resulting from loss of use, data or profits, whether in
#  an action of contract, negligence or other tortious action, arising out of
#  or in connection with the use or performance of this software.
#

-include ../gsfix.make

ifeq ($(GNUSTEP_MAKEFILES),)

$(warning ERROR: Your $(GNUSTEP_MAKEFILES) environment variable is empty !)
$(error Please try again after running ". $(GNUSTEP_MAKEFILES)/GNUstep.sh")

else

# ZNeK: hardcoded this due to removal of support for other runtimes
OBJC_RUNTIME=GNU

GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)

#include libFoundation.make
include $(GNUSTEP_MAKEFILES)/common.make
-include libFoundation.make # not available in make distclean
-include $(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)/$(OBJC_RUNTIME)/config.mak
include ../Version

ifeq ($(gc), yes)
ifeq ($(LIBFOUNDATION_WITH_GC), yes)
# With a recent gnustep-make, we should redefine GNUSTEP_OBJ_DIR_NAME;
# gnustep-make would recompute GNUSTEP_OBJ_DIR from that.  With an old
# gnustep-make, we should redefine GNUSTEP_OBJ_DIR.  We redefine both
# which works in all cases; this doesn't support GNUSTEP_BUILD_DIR
# though.
GNUSTEP_OBJ_DIR = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)-gc
GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)-gc
else # $(LIBFOUNDATION_WITH_GC) == no
GNUSTEP_OBJ_DIR = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
endif
else # $(gc) == no
GNUSTEP_OBJ_DIR = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
GNUSTEP_OBJ_DIR_NAME = $(GNUSTEP_OBJ_PREFIX)/$(GNUSTEP_TARGET_DIR)/$(OBJC_RUNTIME)
endif

LIBRARY_NAME = libFoundation

libFoundation_DLL_DEF = libFoundation.def

ifeq ($(GNUSTEP_TARGET_OS),cygwin32)
ADDITIONAL_CPPFLAGS += -DWIN=1 -D__WIN32__=1
endif

libFoundation_HEADER_FILES_DIR = ..
libFoundation_HEADER_FILES_INSTALL_DIR = /libFoundation

ADDITIONAL_CPPFLAGS += -DLIB_FOUNDATION_LIBRARY=1 -DFD_WITH_GSMAKE=1

ADDITIONAL_INCLUDE_DIRS = \
	-I.. -I$(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)/$(OBJC_RUNTIME)

libFoundation_C_FILES    += cvtutf.c
libFoundation_OBJC_FILES += behavior.m objc-runtime.m common.m realpath.m \
	load.m NSObject.m NSObjectAllocation.m NSObjCRuntime.m NSVMPage.m \
	NSDebug.m NSException.m NSAutoreleasePool.m NSEnumerator.m \
	NSUtilities.m NSHashMap.m NSRange.m NSGeometry.m \
	NSZone.m NSDefaultZone.m NSAllocDebugZone.m StackZone.m \
	NSArray.m NSConcreteArray.m NSDictionary.m NSConcreteDictionary.m \
	NSConcreteMutableDictionary.m \
	NSData.m NSConcreteData.m NSSet.m NSConcreteSet.m \
	NSValue.m NSConcreteValue.m NSNumber.m NSConcreteNumber.m \
	NSString.m NSString+StringEncoding.m NSConcreteString.m \
	NSPathUtilities.m NSConcreteUTF16String.m \
	NSConcreteMutableString.m NSAttributedString.m \
	NSCoder.m NSArchiver.m NSSerialization.m \
	NSCharacterSet.m NSConcreteCharacterSet.m \
	NSMethodSignature.m NSInvocation.m \
	NSNotification.m NSNotificationQueue.m NSNotificationCenter.m \
	NSDate.m NSConcreteDate.m \
	NSScanner.m NSConcreteScanner.m \
	NSCalendarDate.m NSCalendarDateScannerHandler.m NSCalendarDateScanf.m \
	NSTimeZone.m NSConcreteTimeZone.m NSConcreteTimeZoneDetail.m \
	NSProcessInfo.m NSUserDefaults.m NSBundle.m \
	NSThread.m PrivateThreadData.m NSLock.m NSDistributedLock.m \
	NSRunLoop.m NSTimer.m \
	FormatScanner.m PrintfFormatScanner.m \
	DefaultScannerHandler.m PrintfScannerHandler.m \
	NSPosixFileDescriptor.m NSFileHandle.m NSConcreteFileHandle.m \
	NSMappedData.m NSAccount.m NSFileManager.m \
	NSHost.m NSTask.m NSPipe.m UnixSignalHandler.m \
	GarbageCollector.m GCObject.m GCArray.m GCDictionary.m \
	NSFormatter.m NSNumberFormatter.m NSDateFormatter.m NSProxy.m \
	NSFrameInvocation.m NSObjectInvocation.m \
	NSPort.m NSPortNameServer.m NSPortMessage.m NSUndoManager.m \
	NSConnection.m NSPortCoder.m NSURL.m NSURLHandle.m NSFileURLHandle.m \
	NSNull.m NSClassDescription.m \
	NSDecimal.m NSDecimalNumber.m NSSortDescriptor.m NSError.m \
	NSStream.m NSInputStream.m NSOutputStream.m \
	NSExpression.m NSPredicateParser.m \
	NSPredicate.m NSComparisonPredicate.m NSCompoundPredicate.m

ifeq ($(use8bitstringsparser),yes)
libFoundation_OBJC_FILES += PropertyListParser.m
else
libFoundation_OBJC_FILES += PropertyListParserUnichar.m
endif

ifeq ($(GNUSTEP_TARGET_OS),mingw32)
libFoundation_OBJC_FILES += \
	NSConcreteWindowsTask.m		\
	NSConcreteWindowsFileHandle.m
else
ifeq ($(GNUSTEP_TARGET_OS),cygwin32)
libFoundation_OBJC_FILES += \
	NSConcreteWindowsTask.m	\
	NSConcreteWindowsFileHandle.m
else
libFoundation_OBJC_FILES += NSConcreteUnixTask.m
endif
endif

ifeq ($(WITH_FFCALL),yes)
libFoundation_OBJC_FILES            += FFCallInvocation.m
libFoundation_LIBRARIES_DEPEND_UPON += -lcallback -lavcall
endif

libFoundation_HEADER_FILES = NSObject.h NSException.h NSAutoreleasePool.h \
	NSZone.h NSAllocDebugZone.h NSDefaultZone.h \
	NSArray.h NSDictionary.h NSSet.h NSString.h NSData.h NSCharacterSet.h \
	NSUtilities.h NSHashTable.h NSMapTable.h NSGeometry.h NSRange.h \
	NSEnumerator.h NSScanner.h StackZone.h \
	NSNotification.h NSNotificationQueue.h \
	NSInvocation.h NSMethodSignature.h NSObjCRuntime.h \
	NSProcessInfo.h NSUserDefaults.h NSBundle.h \
	NSThread.h NSLock.h NSDistributedLock.h \
	NSRunLoop.h NSTimer.h NSCalendarDate.h \
	NSValue.h NSDate.h NSPosixFileDescriptor.h NSFileHandle.h \
	NSHost.h NSTask.h UnixSignalHandler.h \
	NSPathUtilities.h NSCoder.h NSArchiver.h NSSerialization.h \
	NSConcreteArray.h NSConcreteCharacterSet.h NSConcreteData.h \
	NSConcreteDate.h NSConcreteDictionary.h NSConcreteNumber.h \
	NSConcreteSet.h NSConcreteString.h NSConcreteTimeZoneDetail.h \
	NSConcreteValue.h NSAttributedString.h \
	NSFormatter.h NSNumberFormatter.h NSDateFormatter.h NSProxy.h \
	NSAccount.h NSFileManager.h NSByteOrder.h Foundation.h \
	NSPort.h NSPortNameServer.h NSPortMessage.h NSUndoManager.h \
	NSDebug.h NSConnection.h NSDistantObject.h NSPortCoder.h \
	NSURL.h NSURLHandle.h NSNull.h NSClassDescription.h \
	NSKeyValueCoding.h NSScriptKeyValueCoding.h \
	NSDecimal.h NSDecimalNumber.h NSSortDescriptor.h NSStream.h \
	NSError.h NSTimeZone.h \
	NSExpression.h \
	NSPredicate.h NSComparisonPredicate.h NSCompoundPredicate.h

libFoundation_HEADER_FILES := \
	$(addprefix Foundation/, $(libFoundation_HEADER_FILES))

EXT_HFILES = objc-runtime.h encoding.h NSException.h \
	GarbageCollector.h GCObject.h GCArray.h GCDictionary.h \
	FormatScanner.h PrintfFormatScanner.h \
	DefaultScannerHandler.h PrintfScannerHandler.h \
	support.h \
	$(addprefix exceptions/, FoundationException.h GeneralExceptions.h \
	    NSCoderExceptions.h)
EXT_HFILES := $(addprefix extensions/, $(EXT_HFILES))

libFoundation_HEADER_FILES += $(EXT_HFILES)

EXCEPTION_MFILES = EncodingFormatExceptions.m FoundationException.m \
	GeneralExceptions.m \
	StringExceptions.m NSValueExceptions.m NSCoderExceptions.m \
	NSInvocationExceptions.m NSFileHandleExceptions.m

libFoundation_OBJC_FILES += $(addprefix exceptions/, $(EXCEPTION_MFILES))

EXCEPTION_HFILES = $(EXCEPTION_MFILES:.m=.h) FoundationExceptions.h

libFoundation_HEADER_FILES += \
	$(addprefix Foundation/exceptions/, $(EXCEPTION_HFILES))

# In case we use the Boehm's GC we should add libgc to the libraries as
# we depend on it. This is used by some systems where creating a shared
# library requires specifying the libraries it depends on (like OPENSTEP 4.x)

ADDITIONAL_CPPFLAGS += -Wall -I$(GNUSTEP_TARGET_CPU)/$(GNUSTEP_TARGET_OS)

libFoundation_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

# add the proper dynamic linking library, not being defined in current
# gstep-make versions

ifeq ($(findstring _64, $(GNUSTEP_TARGET_CPU)), _64)
SYSTEM_LIB_DIR += \
	-L$(FHS_INSTALL_ROOT)/lib64	\
	-L/usr/local/lib64		\
	-L/usr/lib64
else
SYSTEM_LIB_DIR += -L$(FHS_INSTALL_ROOT)/lib -L/usr/local/lib -L/usr/lib
endif

libFoundation_LIBRARIES_DEPEND_UPON += -lobjc

ifeq ($(GNUSTEP_TARGET_OS),linux-gnu)
  libFoundation_LIBRARIES_DEPEND_UPON += -lm -ldl
endif

ifeq ($(GNUSTEP_TARGET_OS),openbsd3)
  libFoundation_LIBRARIES_DEPEND_UPON += -lm
endif

ifeq ($(findstring solaris, $(GNUSTEP_TARGET_OS)), solaris)
  libFoundation_LIBARIES_DEPEND_UPON += -lm -ldl
endif

ifeq ($(findstring sysv4.2, $(GNUSTEP_TARGET_OS)), sysv4.2)
  libFoundation_LIBRARIES_DEPEND_UPON += -lm -ldl
endif

include $(GNUSTEP_MAKEFILES)/library.make

include GNUmakefile.postamble

endif
