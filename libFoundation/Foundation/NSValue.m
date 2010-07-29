/* 
   NSValue.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/NSValueExceptions.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>

#include <extensions/objc-runtime.h>

#include "NSConcreteValue.h"
#include "NSConcreteNumber.h"

@implementation NSValue

/* 
 * Returns concrete class for a given encoding 
 * Should we return NSNumbers ?
 */

+ (Class)concreteClassForObjCType:(const char*)type
{
    /* Let someone else deal with this error */
    if (!type)
	[[[NSValueException new] setReason:@"NULL type"] raise];

    if (Strlen(type) == 1) {
	switch(*type) {
	    case _C_CHR:	return [NSCharNumber class];
	    case _C_UCHR:	return [NSUCharNumber class];
	    case _C_SHT:	return [NSShortNumber class];
	    case _C_USHT:	return [NSUShortNumber class];
	    case _C_INT:	return [NSIntNumber class];
	    case _C_UINT:	return [NSUIntNumber class];
	    case _C_LNG:	return [NSLongNumber class];
	    case _C_ULNG:	return [NSULongNumber class];
	    case _C_FLT:	return [NSFloatNumber class];
	    case _C_DBL:	return [NSDoubleNumber class];
	    case _C_ID:		return [NSNonretainedObjectValue class];
	    case 'q':		return [NSLongLongNumber class];
	    case 'Q':		return [NSULongLongNumber class];
	}
    }
    else {
	if(!Strcmp(@encode(NSPoint), type))
	    return [NSPointValue class];
	else if(!Strcmp(@encode(NSRect), type))
	    return [NSRectValue class];
	else if(!Strcmp(@encode(NSSize), type))
	    return [NSSizeValue class];
	else if(!Strcmp(@encode(void*), type))
	    return [NSPointerValue class];
    }							

    return nil;
}

// Allocating and Initializing 

+ (NSValue *)valueWithBytes:(const void*)value objCType:(const char*)type
{
    return [self value:value withObjCType:type];
}

+ (NSValue *)value:(const void*)value withObjCType:(const char*)type
{
    Class theClass = [self concreteClassForObjCType:type];

    if (theClass)
        return AUTORELEASE([[theClass alloc]
                               initValue:value withObjCType:type]);
    else
	return AUTORELEASE([[NSConcreteValue allocForType:type zone:nil]
                               initValue:value withObjCType:type]);
}
		
+ (NSValue *)valueWithNonretainedObject:(id)anObject
{
    return AUTORELEASE([[NSNonretainedObjectValue alloc] 
                           initValue:&anObject withObjCType:@encode(id)]);
}
	
+ (NSValue *)valueWithPointer:(const void*)pointer
{
    return AUTORELEASE([[NSPointerValue alloc] 
                           initValue:&pointer withObjCType:@encode(void*)]);
}

+ (NSValue *)valueWithPoint:(NSPoint)point
{
    return AUTORELEASE([[NSPointValue alloc] 
                           initValue:&point withObjCType:@encode(NSPoint)]);
}

+ (NSValue *)valueWithRect:(NSRect)rect
{
    return AUTORELEASE([[NSRectValue alloc] 
                           initValue:&rect withObjCType:@encode(NSRect)]);
}
 
+ (NSValue *)valueWithSize:(NSSize)size
{
    return AUTORELEASE([[NSSizeValue alloc] 
                           initValue:&size withObjCType:@encode(NSSize)]);
}

- (id)initWithBytes:(const void *)value objCType:(const char *)type
{
    (void)AUTORELEASE(self);
    return [[[self class] alloc] valueWithBytes:value objCType:type];
}

- (BOOL)isEqual:(id)aValue
{
    if ([aValue isKindOfClass:[NSValue class]])
	return [self isEqualToValue:aValue];
    else
	return NO;
}

- (BOOL)isEqualToValue:(NSValue *)aValue
{
    if (Strcmp([self objCType], [aValue objCType]) != 0)
        /* not the same type */
        return NO;

    if (memcmp([self valueBytes], [aValue valueBytes],
               objc_sizeof_type([self objCType])) != 0)
        /* not the same value */
        return NO;
    
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Value with objc type '%s'>", 
                       [self objCType]];
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else {
	Class theClass = [isa concreteClassForObjCType:[self objCType]];
	return [[theClass allocWithZone:zone]
                          initValue:[self valueBytes]
                          withObjCType:[self objCType]];
    }
}

// Accessing Data - implemented in concrete subclasses

- (void *)valueBytes
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (void)getValue:(void*)value
{
    [self subclassResponsibility:_cmd];
}

- (const char*)objCType
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (id)nonretainedObjectValue
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (void*)pointerValue
{
    [self subclassResponsibility:_cmd];
    return NULL;
} 

- (NSRect)rectValue
{
    [self subclassResponsibility:_cmd];
    return NSMakeRect(0,0,0,0);
}

- (NSSize)sizeValue
{
    [self subclassResponsibility:_cmd];
    return NSMakeSize(0,0);
}

- (NSPoint)pointValue
{
    [self subclassResponsibility:_cmd];
    return NSMakePoint(0,0);
}

// NSCoding

- (id)replacementObjectForCoder:(NSCoder *)anEncoder
{
    return self;
}

- (Class)classForCoder
{
    return [NSValue class];
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    const char* objctype = [self objCType];
    void* data = [self valueBytes];

    [coder encodeValueOfObjCType:@encode(char*) at:&objctype];
    [coder encodeValueOfObjCType:objctype at:data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    char* type;
    void* data;
    id value;

    [coder decodeValueOfObjCType:@encode(char*) at:&type];
    data = Malloc (objc_sizeof_type(type));
    [coder decodeValueOfObjCType:type at:(void*)data];
    value = [NSValue valueWithBytes:data objCType:type];
    lfFree(data);
    return value;
}

@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

