/* 
   NSSerialization.h

   Copyright (C) 2000 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge.hess@mdlink.de)

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

#include <Foundation/NSSerialization.h>
#include <Foundation/NSData.h>

@implementation NSSerializer

+ (void)serializePropertyList:(id)_plist intoData:(NSMutableData *)_data
{
    [self notImplemented:_cmd];
}

+ (NSData *)serializePropertyList:(id)_plist
{
    NSMutableData *md;
    NSData        *d;

    md = [[NSMutableData alloc] initWithCapacity:4096];
    [self serializePropertyList:_plist intoData:md];
    d = [md copy];
    RELEASE(md);
    return AUTORELEASE(d);
}

@end /* NSSerializer */

@implementation NSDeserializer


+ (id)deserializePropertyListFromData:(NSData *)_data
  atCursor:(unsigned *)_cursor
  mutableContainers:(BOOL)_flag
{
    return nil;
}

+ (id)deserializePropertyListLazilyFromData:(NSData *)_data
  atCursor:(unsigned *)_cursor
  length:(unsigned)_len
  mutableContainers:(BOOL)_flag
{
    return nil;
}

+ (id)deserializePropertyListFromData:(NSData *)_data
  mutableContainers:(BOOL)_flag
{
    unsigned cursor;

    return [self deserializePropertyListFromData:_data
                 atCursor:&cursor
                 mutableContainers:_flag];
}

@end /* NSDeserializer */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

