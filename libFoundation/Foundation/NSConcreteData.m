/* 
   NSConcreteData.m

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

#include <Foundation/common.h>
#include <extensions/objc-runtime.h>

#include "NSConcreteData.h"

/*
 * Subdata of a concrete data
 */

@implementation NSConcreteDataRange

- (id)initWithData:(NSData *)data range:(NSRange)range
{
    self->bytes  = (char *)[data bytes] + range.location;
    self->length = range.length;
    //range        = range;
    self->parent = RETAIN(data);
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    return [[NSData allocWithZone:zone]
	       initWithBytes:self->bytes length:self->length];
}

- (const void *)bytes
{
    return self->bytes;
}

- (unsigned int)length
{
    return self->length;
}

- (void)dealloc
{
    RELEASE(self->parent);
    [super dealloc];
}

@end /* NSConcreteDataRange */

/*
* Concrete data
*/

@implementation NSConcreteData

- (id)initWithBytes:(const void *)_bytes length:(unsigned int)_length
{
    void *copy_of_bytes = NSZoneMallocAtomic([self zone], _length);
    memcpy(copy_of_bytes, _bytes, _length);
    return [self initWithBytesNoCopy:copy_of_bytes length:_length];
}

- (id)initWithBytesNoCopy:(void*)_bytes
    length:(unsigned int)_length
{
    self->length = _length;
    self->bytes  = _bytes;
    return self;
}

- (id)init
{
    return [self initWithBytesNoCopy:NULL length:0];
}

- (id)copyWithZone:(NSZone *)zone
{
    static Class DataClass = Nil;
    if ([self zone] == zone)
	return RETAIN(self);
    if (DataClass == Nil)
	DataClass = [NSData class];
    return [[DataClass allocWithZone:zone]
	       initWithBytes:self->bytes length:self->length];
}

- (const void *)bytes
{
    return self->bytes;
}

- (unsigned int)length
{
    return self->length;
}

- (void)dealloc
{
    if (self->bytes) lfFree(self->bytes);
    [super dealloc];
}

@end /* NSConcreteData */

/*
* Mutable data
*/

@implementation NSConcreteMutableData

+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized) {
	initialized = YES;
	//class_add_behavior(self, [NSConcreteData class]);
    }
}

- (id)initWithBytes:(const void *)_bytes length:(unsigned int)_length
{
    void *copy_of_bytes = NSZoneMallocAtomic([self zone], _length);
    memcpy(copy_of_bytes, _bytes, _length);
    return [self initWithBytesNoCopy:copy_of_bytes length:_length];
}
- (id)initWithBytesNoCopy:(void*)_bytes length:(unsigned int)_length {
    self->length = self->capacity = _length;
    self->bytes  = _bytes;
    return self;
}

- (id)initWithCapacity:(unsigned int)_capacity
{
    if ((self = [self initWithLength:_capacity])) {
	self->length = 0;
    }
    return self;
}

- (id)initWithLength:(unsigned int)_length
{
    self->capacity = self->length = _length;
    self->bytes = NSZoneMallocAtomic([self zone], self->capacity);
    memset(self->bytes, 0, self->capacity);
    return self;
}

- (void)dealloc
{
    if (self->bytes) lfFree(self->bytes);
    [super dealloc];
}

- (const void *)bytes
{
    return self->bytes;
}

- (unsigned int)length
{
    return self->length;
}
- (unsigned int)capacity
{
    return self->capacity;
}

- (void)increaseLengthBy:(unsigned int)extraLength
{
    if((length += extraLength) >= capacity) {
	unsigned int extent = length - capacity;

	bytes = NSZoneRealloc(
	    bytes ? NSZoneFromPointer(bytes) : [self zone],
	    bytes, length);
	memset(bytes + capacity, 0, extent);
	capacity = length;
    }
}

- (void *)mutableBytes
{
    return self->bytes;
}

- (void)setLength:(unsigned int)_length
{
    if(_length <= capacity)
	self->length = _length;
    else
        [self increaseLengthBy:(_length - self->length)];
}

- (void)increaseCapacityBy:(unsigned int)extraCapacity
{
    if (extraCapacity == 0)
        return;
    self->capacity += extraCapacity;
    self->bytes = NSZoneRealloc(
	self->bytes ? NSZoneFromPointer(self->bytes) : [self zone],
	self->bytes, self->capacity);
}

- (void)appendBytes:(const void *)_bytes
  length:(unsigned int)_length
{
    if (_length == 0)
        return;
    
    if((self->length + _length) >= self->capacity)
	[self increaseCapacityBy:(self->length + _length - self->capacity)];
    memcpy(self->bytes + self->length, _bytes, _length);
    self->length += _length;
}

@end /* NSConcreteMutableData */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
