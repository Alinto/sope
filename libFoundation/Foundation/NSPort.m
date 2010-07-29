/* 
   NSPort.m

   Copyright (C) 1999 Helge Hess.
   All rights reserved.

   Author: Helge Hess <hh@mdlink.de>

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

#include <Foundation/NSPort.h>
#include <Foundation/NSString.h>
#include <common.h>

@implementation NSPort

/* port creation */

+ (NSPort *)port
{
    return [self notImplemented:_cmd];
}
+ (NSPort *)portWithMachPort:(int)aMachPort
{
    return [self notImplemented:_cmd];
}

- (id)init
{
    return [self notImplemented:_cmd];
}
- (id)initWithMachPort:(int)aMachPort
{
    return [self notImplemented:_cmd];
}

/* mach port */

- (int)machPort
{
    [self notImplemented:_cmd];
    return -1;
}

/* delegate */

- (void)setDelegate:(id)anObject
{
    [self notImplemented:_cmd];
}
- (id)delegate
{
    return [self notImplemented:_cmd];
}

/* validation */

- (void)invalidate
{
    [self notImplemented:_cmd];
}
- (BOOL)isValid
{
    [self notImplemented:_cmd];
    return NO;
}

/* sending messages */

- (BOOL)sendBeforeDate:(NSDate *)limitDate
  components:(NSMutableArray *)components
  from:(NSPort *)receivePort
  reserved:(unsigned)headerSpaceReserved
{
    [self notImplemented:_cmd];
    return NO;
}
- (BOOL)sendBeforeDate:(NSDate *)limitDate
  msgid:(unsigned)_msgid
  components:(NSMutableArray *)components
  from:(NSPort *)receivePort
  reserved:(unsigned)headerSpaceReserved
{
    [self notImplemented:_cmd];
    return NO;
}

- (unsigned)reservedSpaceLength
{
    [self notImplemented:_cmd];
    return 0;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder
{
    [self notImplemented:_cmd];
}

- (id)initWithCoder:(NSCoder *)_coder
{
    return [self notImplemented:_cmd];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone
{
    return RETAIN(self);
}

@end

LF_DECLARE NSString *NSPortDidBecomeInvalidNotification =
  @"NSPortDidBecomeInvalidNotificationName";

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
