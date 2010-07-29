/*
   NSFileHandle.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: May 1997

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <Foundation/common.h>

#if HAVE_SYS_STAT_H
# include <sys/stat.h>
#endif

#include <fcntl.h>
#include <sys/types.h>

#include <Foundation/NSFileHandle.h>
#include "NSConcreteFileHandle.h"

@implementation NSFileHandle

static NSFileHandle *nullDevice = nil;

+ (void)initialize
{
#ifdef WIN32
    static WSADATA wsaData;
    WSAStartup(MAKEWORD(1, 1), &wsaData);
#endif
}

+ (id)allocWithZone:(NSZone*)zone
{
    return (self == [NSFileHandle class])
	? [NSConcreteFileHandle allocWithZone:zone] 
	: (id)NSAllocateObject(self, 0, zone);
}

+ (id)fileHandleForReadingAtPath:(NSString*)path
{
    return [NSConcreteFileHandle fileHandleForReadingAtPath:path];
}
+ (id)fileHandleForWritingAtPath:(NSString*)path
{
    return [NSConcreteFileHandle fileHandleForWritingAtPath:path];
}
+ (id)fileHandleForUpdatingAtPath:(NSString*)path
{
    return [NSConcreteFileHandle fileHandleForUpdatingAtPath:path];
}

#ifdef __MINGW32__

+ (id)fileHandleWithStandardInput
{
    return AUTORELEASE([[self alloc] initWithNativeHandle:
					 GetStdHandle(STD_INPUT_HANDLE)]);
}
+ (id)fileHandleWithStandardOutput
{
    return AUTORELEASE([[self alloc] initWithNativeHandle:
					 GetStdHandle(STD_OUTPUT_HANDLE)]);
}
+ (id)fileHandleWithStandardError
{
    return AUTORELEASE([[self alloc] initWithNativeHandle:
					 GetStdHandle(STD_ERROR_HANDLE)]);
}

#else /* !__MINGW32__ */

+ (id)fileHandleWithStandardInput
{
    return AUTORELEASE([[self alloc] initWithFileDescriptor:0]);
}

+ (id)fileHandleWithStandardOutput
{
    return AUTORELEASE([[self alloc] initWithFileDescriptor:1]);
}

+ (id)fileHandleWithStandardError
{
    return AUTORELEASE([[self alloc] initWithFileDescriptor:2]);
}

#endif /* !__MINGW32__ */

+ (id)fileHandleWithNullDevice
{
    if (!nullDevice)
        nullDevice = [NSNullDeviceFileHandle new];

    return nullDevice;
}

@end /* NSFileHandle */


LF_DECLARE NSString *NSFileHandleConnectionAcceptedNotification
    = @"NSFileHandleConnectionAcceptedNotification";

LF_DECLARE NSString *NSFileHandleReadCompletionNotification
    = @"NSFileHandleReadCompletionNotification";

LF_DECLARE NSString *NSFileHandleReadToEndOfFileCompletionNotification
    = @"NSFileHandleReadToEndOfFileCompletionNotification";

LF_DECLARE NSString *NSFileHandleNotificationFileHandleItem
    = @"NSFileHandleNotificationFileHandleItem";

LF_DECLARE NSString *NSFileHandleNotificationDataItem
    = @"NSFileHandleNotificationDataItem";

NSString* NSFileHandleNotificationMonitorModes
    = @"NSFileHandleNotificationMonitorModes";

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
