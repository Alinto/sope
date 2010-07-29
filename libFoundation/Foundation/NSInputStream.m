/* 
   NSInpuStream.m

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

@implementation NSInputStream

/* TODO: this is probably a class cluster? */

+ (id)inputStreamWithData:(NSData *)_data 
{
    return [[[self alloc] initWithData:_data] autorelease];
}
+ (id)inputStreamWithFileAtPath:(NSString *)_path
{
    return [[[self alloc] initWithFileAtPath:_path] autorelease];
}

- (id)initWithData:(NSData *)_data
{
    [self release];
    return [self notImplemented:_cmd];
}
- (id)initWithFileAtPath:(NSString *)_path
{
    [self release];
    return [self notImplemented:_cmd];
}

/* operations */

- (int)read:(void *)_buf maxLength:(unsigned int)_len
{
    return -1;
}

- (BOOL)getBuffer:(void **)_buf length:(unsigned int *)_len
{
    return NO;
}

- (BOOL)hasBytesAvailable
{
    return NO;
}

@end /* NSInputStream */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
