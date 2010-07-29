/* 
   NSCoder.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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

#include "common.h"

#include <Foundation/NSCoder.h>
#include <Foundation/NSZone.h>
#include <extensions/objc-runtime.h>

@implementation NSCoder

- (void)encodeArrayOfObjCType:(const char*)types
	count:(unsigned int)count
	at:(const void*)array
{
    unsigned int i, offset, item_size = objc_sizeof_type(types);
    IMP imp = [self methodForSelector:@selector(encodeValueOfObjCType:at:)];

    for(i = offset = 0; i < count; i++, offset += item_size) {
        (*imp)(self, @selector(encodeValueOfObjCType:at:),
		types, (char*)array + offset);
	types = objc_skip_typespec(types);
	item_size = objc_sizeof_type(types);
    }
}

- (void)encodeBycopyObject:(id)anObject
{
    [self encodeObject:anObject];
}

- (void)encodeConditionalObject:(id)anObject
{
    [self encodeObject:anObject];
}

- (void)encodeDataObject:(NSData*)data
{
    [self encodeObject:data];
}

- (void)encodeObject:(id)anObject
{
    [self subclassResponsibility:_cmd];
}

- (void)encodePropertyList:(id)aPropertyList
{
    [self encodeObject:aPropertyList];
}

- (void)encodeRootObject:(id)rootObject
{
    [self encodeObject:rootObject];
}

- (void)encodeValueOfObjCType:(const char*)type
	at:(const void*)address
{
    [self subclassResponsibility:_cmd];
}

- (void)encodeValuesOfObjCTypes:(const char*)types, ...
{
    va_list ap;
    IMP imp = [self methodForSelector:@selector(encodeValueOfObjCType:at:)];
    
    va_start(ap, types);
    for(; types && *types; types = objc_skip_typespec(types)) {
        (*imp)(self, @selector(encodeValueOfObjCType:at:),
		types, va_arg(ap, void*));
    }
    va_end(ap);
}

- (void)encodePoint:(NSPoint)point
{
    [self encodeValueOfObjCType:@encode(NSPoint) at:&point];
}

- (void)encodeSize:(NSSize)size
{
    [self encodeValueOfObjCType:@encode(NSSize) at:&size];
}

- (void)encodeRect:(NSRect)rect
{
    [self encodeValueOfObjCType:@encode(NSRect) at:&rect];
}

- (void)decodeArrayOfObjCType:(const char*)types
	count:(unsigned)count
	at:(void*)address
{
    unsigned i, offset, item_size = objc_sizeof_type(types);
    IMP imp = [self methodForSelector:@selector(decodeValueOfObjCType:at:)];

    for(i = offset = 0; i < count; i++, offset += item_size) {
        (*imp)(self, @selector(decodeValueOfObjCType:at:),
		types, (char*)address + offset);
	types = objc_skip_typespec(types);
	item_size = objc_sizeof_type(types);
    }
}

- (NSData*)decodeDataObject
{
    return [self decodeObject];
}

- (id)decodeObject
{
    return [self subclassResponsibility:_cmd];
}

- (id)decodePropertyList
{
    return [self decodeObject];
}

- (void)decodeValueOfObjCType:(const char*)type
	at:(void*)address
{
    [self subclassResponsibility:_cmd];
}

- (void)decodeValuesOfObjCTypes:(const char*)types, ...
{
    va_list ap;
    IMP imp = [self methodForSelector:@selector(decodeValueOfObjCType:at:)];

    va_start(ap, types);
    for(;types && *types; types = objc_skip_typespec(types))
        (*imp)(self, @selector(decodeValueOfObjCType:at:),
		types, va_arg(ap, void*));
    va_end(ap);
}

- (NSPoint)decodePoint
{
    NSPoint point;

    [self decodeValueOfObjCType:@encode(NSPoint) at:&point];
    return point;
}

- (NSSize)decodeSize
{
    NSSize size;

    [self decodeValueOfObjCType:@encode(NSSize) at:&size];
    return size;
}

- (NSRect)decodeRect
{
    NSRect rect;

    [self decodeValueOfObjCType:@encode(NSRect) at:&rect];
    return rect;
}

- (NSZone*)objectZone
{
    return NSDefaultMallocZone();
}

- (void)setObjectZone:(NSZone*)zone
{
}

- (unsigned int)systemVersion
{
    [self notImplemented:_cmd];
    return 0;
}

- (unsigned int)versionForClassName:(NSString*)className
{
    [self subclassResponsibility:_cmd];
    return 0;
}

@end /* NSCoder */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

