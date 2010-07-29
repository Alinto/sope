/* 
   NSOutputStream.m

   Copyright (C) 2003 SKYRIX Software AG, Helge Hess.
   All rights reserved.
   
   Author: Helge Hess <helge.hess@opengroupware.org>
   
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

#include <Foundation/NSStream.h>
#include <common.h>

@implementation NSOutputStream

/* TODO: this is probably a class cluster? */

+ (id)outputStreamToMemory
{
    return [[[self alloc] initToMemory] autorelease];
}
+ (id)outputStreamToBuffer:(void *)_buf capacity:(unsigned int)_capacity
{
    return [[[self alloc] initToBuffer:_buf capacity:_capacity] autorelease];
}
+ (id)outputStreamToFileAtPath:(NSStream *)_path append:(BOOL)_append
{
    return [[[self alloc] initToFileAtPath:_path append:_append] autorelease];
}

- (id)initToMemory
{
    [self release];
    return [self notImplemented:_cmd];
}

- (id)initToBuffer:(void *)_buf capacity:(unsigned int)_capacity
{
    [self release];
    return [self notImplemented:_cmd];
}

- (id)initToFileAtPath:(NSStream *)_path append:(BOOL)_append
{
    [self release];
    return [self notImplemented:_cmd];
}

/* operations */

- (BOOL)hasSpaceAvailable 
{
    return YES;
}
- (int)write:(const void *)buffer maxLength:(unsigned int)len
{
    return -1; // -1 error, 0 EOF
}

@end /* NSOutputStream */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
