/* 
   NSConcreteValue.m

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
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/exceptions/NSValueExceptions.h>

#include <extensions/objc-runtime.h>

#include "NSConcreteValue.h"

/*
 * Abstract superclass of concrete value classes
 */

@implementation NSConcreteValue

+ allocForType:(const char*)type zone:(NSZone*)zone
{
    int dataSize = objc_sizeof_type(type);
    id  value = NSAllocateObject([NSConcreteObjCValue class], dataSize, zone);

    return value;
}

- initValue:(const void*)value withObjCType:(const char*)type
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (void*)valueBytes
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (id)nonretainedObjectValue
{
    [[[NSValueException new]
	    setReason:@"this value does not contain an id type value"] raise];
    return nil;
}

- (void*)pointerValue
{
    [[[NSValueException new]
	    setReason:@"this value does not contain a void* value"] raise];
    return NULL;
}

- (NSRect)rectValue
{
    [[[NSValueException new]
	    setReason:@"this value does not contain a NSRect"] raise];
    return NSMakeRect(0,0,0,0);
}
 
- (NSSize)sizeValue
{
    [[[NSValueException new]
	    setReason:@"this value does not contain a NSSize"] raise];
    return NSMakeSize(0,0);
}
 
- (NSPoint)pointValue
{
    [[[NSValueException new]
	    setReason:@"this value does not contain a NSPoint"] raise];
   return NSMakePoint(0,0);
}

@end

/*
 * Any type concrete value class
 */

@implementation NSConcreteObjCValue

// Allocating and Initializing 

- initValue:(const void*)value withObjCType:(const char*)type
{
    int	size;
    
    if (!value || !type) 
	[[[NSValueException new]
		setReason:@"null value or type"] raise];
		
    self = [super init];
    objctype = Strdup(type);
    size = objc_sizeof_type(type);
    memcpy(data, value, size);
    return self;
}

- (void)dealloc
{
    lfFree(objctype);
    [super dealloc];
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSConcreteObjCValue allocForType:objctype zone:zone]
		    initValue:(void*)data withObjCType:objctype];
}

// Accessing Data 

- (void*)valueBytes
{
    return data;
}

- (void)getValue:(void*)value
{
    if (!value)
	[[[NSValueException new]
		setReason:@"NULL buffer in -getValue"] raise];
    else 
	memcpy(value, data, objc_sizeof_type(objctype));
}

- (const char*)objCType
{
    return objctype;
}
 
- (void*)pointerValue
{
    if (*objctype != _C_PTR)
	[[[NSValueException new]
		setReason:@"this value does not contain a pointer"] raise];
    return *((void **)data);
} 

- (NSRect)rectValue
{
    if (Strcmp(objctype, @encode(NSRect)))
	[[[NSValueException new]
		setReason:@"this value does not contain a NSRect object"] raise];
    return *((NSRect*)data);
}
 
- (NSSize)sizeValue
{
    if (Strcmp(objctype, @encode(NSSize)))
	[[[NSValueException new]
		setReason:@"this value does not contain a NSSize object"] raise];
    return *((NSSize*)data);
}
 
- (NSPoint)pointValue
{
    if (Strcmp(objctype, @encode(NSPoint)))
	[[[NSValueException new]
		setReason:@"this value does not contain a NSPoint object"] raise];
    return *((NSPoint*)data);
}

- (unsigned)hash
{
    return hashjb (objctype, Strlen (objctype));
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<Value with objc type '%s'>", 
	[self objCType]];
}

@end /* NSConcreteObjCValue */

/*
 * Non retained object concrete value
 */

@implementation NSNonretainedObjectValue

// Allocating and Initializing 

- (id)initValue:(const void *)value withObjCType:(const char *)type
{
    data = *(id*)value;
    return self;
}

- (BOOL)isEqual:(id)aValue
{
    if (aValue == nil)
	return NO;
    
    // Note: we do not check the aValue class, I think this is an intended
    //       optimization? (we could quickly check using *(Class *)obj?)
    return Strcmp([self objCType], [(NSValue *)aValue objCType]) == 0
	    && [[self nonretainedObjectValue]
		   isEqual:[(NSValue *)aValue nonretainedObjectValue]];
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSNonretainedObjectValue alloc]
		initValue:(void*)&data withObjCType:NULL];
}

// Accessing Data 

- (void*)valueBytes
{
    return &data;
}

- (void)getValue:(void*)value
{
    if (!value)
	[[[NSValueException new]
		setReason:@"NULL buffer in -getValue"] raise];
    else 
	*(id*)value = data;
}

- (const char*)objCType
{
    return @encode(id);
}
 
-(id)nonretainedObjectValue;
{
    return data;
} 

- (unsigned)hash
{
    return (unsigned long)data;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<Value with object %@>", data];
}

/* NSCoding */

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(id) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(id) at:&data];
    return self;
}

@end /* NSNonretainedObjectValue */

/*
 * Void Pointer concrete value
 */

@implementation NSPointerValue

// Allocating and Initializing 

- initValue:(const void*)value withObjCType:(const char*)type
{
    data = *(void**)value;
    return self;
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSNonretainedObjectValue alloc]
		    initValue:(void*)&data withObjCType:NULL];
}

// Accessing Data 

- (void*)valueBytes
{
    return &data;
}

- (void)getValue:(void*)value
{
    if (!value)
	[[[NSValueException new]
		setReason:@"NULL buffer in -getValue"] raise];
    else 
	    *(void**)value = data;
}

- (const char*)objCType
{
    return @encode(void*);
}
 
- (void*)pointerValue;
{
    return data;
} 

- (unsigned)hash
{
    return (unsigned long)data;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<Value with pointer 0x%08x>", data];
}

@end /* NSPointerValue */

/*
 * NSRect concrete value
 */

@implementation NSRectValue

// Allocating and Initializing 

- initValue:(const void*)value withObjCType:(const char*)type
{
    data = *(NSRect*)value;
    return self;
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSRectValue alloc]
		initValue:(void*)&data withObjCType:NULL];
}

// Accessing Data 

- (void*)valueBytes
{
    return &data;
}

- (void)getValue:(void*)value
{
    if (!value)
	[[[NSValueException new]
		setReason:@"NULL buffer in -getValue"] raise];
    else 
	*(NSRect*)value = data;
}

- (const char*)objCType
{
    return @encode(NSRect);
}
 
- (NSRect)rectValue;
{
    return data;
} 

- (unsigned)hash
{
    return (unsigned)(data.origin.x + data.origin.y
	    + data.size.width + data.size.height);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<Value with rect %@>",
	NSStringFromRect(data)];
}

/* NSCoding */

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(NSRect) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(NSRect) at:&data];
    return self;
}

@end /* NSRectValue */

/*
 * NSSize concrete value
 */

@implementation NSSizeValue

// Allocating and Initializing 

- initValue:(const void*)value withObjCType:(const char*)type
{
    data = *(NSSize*)value;
    return self;
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSSizeValue alloc]
		    initValue:(void*)&data withObjCType:NULL];
}

// Accessing Data 

- (void*)valueBytes
{
    return &data;
}

- (void)getValue:(void*)value
{
    if (!value)
	[[[NSValueException new]
		setReason:@"NULL buffer in -getValue"] raise];
    else 
	*(NSSize*)value = data;
}

- (const char*)objCType
{
    return @encode(NSSize);
}
 
- (NSPoint)pointValue;
{
    return NSMakePoint(data.width, data.height);
} 

- (NSSize)sizeValue;
{
    return data;
} 

- (unsigned)hash
{
    return (unsigned)(data.width + data.height);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<Value with size %@>",
	NSStringFromSize(data)];
}

/* NSCoding */

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(NSSize) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(NSSize) at:&data];
    return self;
}

@end /* NSSizeValue */

/*
 * NSPoint concrete value
 */

@implementation NSPointValue

// Allocating and Initializing 

- initValue:(const void*)value withObjCType:(const char*)type
{
    data = *(NSPoint*)value;
    return self;
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSPointValue alloc]
		    initValue:(void*)&data withObjCType:NULL];
}

// Accessing Data 

- (void*)valueBytes
{
    return &data;
}

- (void)getValue:(void*)value
{
    if (!value)
	[[[NSValueException new]
		setReason:@"NULL buffer in -getValue"] raise];
    else 
	*(NSPoint*)value = data;
}

- (const char*)objCType
{
    return @encode(NSPoint);
}
 
- (NSPoint)pointValue;
{
    return data;
} 

- (NSSize)sizeValue;
{
    return NSMakeSize(data.x, data.y);
} 

- (unsigned)hash
{
    return (unsigned)(data.x + data.y);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<Value with point %@>",
	NSStringFromPoint(data)];
}

/* NSCoding */

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(NSPoint) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(NSPoint) at:&data];
    return self;
}

@end /* NSPointValue */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

