/* 
   NSUtilities.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSByteOrder.h>
#include <config.h>

#if defined(HAVE_WINDOWS_H)
#  include <windows.h>
#endif

extern NSRecursiveLock *libFoundationLock;

/* 
 * Log a Message 
 */

static Class NSStringClass              = Nil;
static Class NSCalendarDateClass        = Nil;
static Class NSProcessInfoClass         = Nil;

void NSLog(NSString *format, ...)
{
    va_list ap;
    
    va_start(ap, format);
    NSLogv(format, ap);
    va_end(ap);
}

void NSLogv(NSString *format, va_list args)
{
    NSString       *message;
    NSCalendarDate *date;
    
    if (NSStringClass == Nil)
        NSStringClass = [NSString class];
    if (NSCalendarDateClass == Nil)
        NSCalendarDateClass = [NSCalendarDate class];
    if (NSProcessInfoClass == Nil)
        NSProcessInfoClass = [NSProcessInfo class];
    
    message = [[NSStringClass alloc] initWithFormat:format arguments:args];
    date    = [[NSCalendarDateClass alloc] init];
    
    [libFoundationLock lock];
    
    fprintf(stderr,
            "%s %s [%d]: %s\n",
            [[date descriptionWithCalendarFormat:@"%b %d %H:%M:%S"] cString],
            [[[NSProcessInfoClass processInfo] processName] cString],
#if defined(__MINGW32__)
            (int)GetCurrentProcessId(),
#else
            getpid(),
#endif
            [message cString]);
    
    [libFoundationLock unlock];
    
    RELEASE(date);
    RELEASE(message);
}

/* Support function for debugger */
NSString *_NSNewStringFromCString (const char* cString)
{
    if (NSStringClass == Nil)
        NSStringClass = [NSString class];
    return [NSStringClass stringWithCString:cString];
}

/* NSByteOrder.h */

unsigned int NSHostByteOrder(void) {
#if WORDS_BIGENDIAN
    return NS_BigEndian;
#else
    return NS_LittleEndian;
#endif
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
