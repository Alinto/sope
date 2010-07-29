/* 
   NSConcreteCharacterSet.m

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
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include "NSConcreteCharacterSet.h"

/*
 * NSRangeCharacterSet
 */

@implementation NSRangeCharacterSet

- init
{
    NSRange aRange = {0,0};
    return [self initWithRange:aRange inverted:NO];
}

- initWithRange:(NSRange)aRange
{
    return [self initWithRange:aRange inverted:NO];
}

- initWithRange:(NSRange)aRange inverted:(BOOL)inv
{
    [super init];
    range = aRange;
    inverted = inv;
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (NSData *)bitmapRepresentation
{
    char* bytes = CallocAtomic(1, BITMAPDATABYTES);
    unsigned i;
    
    for (i=MIN(range.location+range.length-1, BITMAPDATABYTES);
		i >= range.location; i--)
	SETBIT(bytes, i);
    
    return [NSData dataWithBytesNoCopy:bytes 
	    length:BITMAPDATABYTES];
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
    return inverted ^ (range.location<=aCharacter &&
	    aCharacter<range.location+range.length);
}

- (NSCharacterSet *)invertedSet
{
    return AUTORELEASE([[NSRangeCharacterSet alloc]
                           initWithRange:range inverted:!inverted]);
}

// NSCopying

- copyWithZone:(NSZone*)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else {
	return [[NSRangeCharacterSet allocWithZone:zone]
		initWithRange:range inverted:inverted];
    }
}

@end /* NSRangeCharacterSet */

/*
 * NSStringCharacterSet
 */

@implementation NSStringCharacterSet

- init
{
    return [self initWithString:@"" inverted:NO];
}

- initWithString:(NSString*)aString
{
    return [self initWithString:aString inverted:NO];
}

- initWithString:(NSString*)aString inverted:(BOOL)inv
{
    [super init];
    string = [aString copy];
    inverted = inv;
    return self;
}

- (void)dealloc
{
    RELEASE(string);
    [super dealloc];
}

- (NSData *)bitmapRepresentation
{
    char*	bytes = CallocAtomic(1, BITMAPDATABYTES);
    int		i;
    unichar	c;
    
    for (i=[string length]; i>=0; i--) {
	    c = [string characterAtIndex:i];
	SETBIT(bytes, c);
    }
    
    return [NSData dataWithBytesNoCopy:bytes 
	    length:BITMAPDATABYTES];
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
    int i;
    
    for (i=[string length]; i>=0; i++)
	if (aCharacter == [string characterAtIndex:i])
	    return !inverted;
    return inverted;
}

- (NSCharacterSet *)invertedSet
{
    return AUTORELEASE([[NSStringCharacterSet alloc]
                           initWithString:string inverted:!inverted]);
}

// NSCopying

- copyWithZone:(NSZone*)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else {
	return [[NSStringCharacterSet allocWithZone:zone] 
		initWithString:string];
    }
}

@end /* NSStringCharacterSet */

/*
 * NSBitmapCharacterSet
 */

@implementation NSBitmapCharacterSet

- (id)init
{
    return [self initWithBitmapRepresentation:
	    [[NSCharacterSet emptyCharacterSet] bitmapRepresentation] 
	    inverted:NO];
}

- (id)initWithBitmapRepresentation:(id)aData
{
    return [self initWithBitmapRepresentation:aData inverted:NO];
}

- (id)initWithBitmapRepresentation:(id)aData inverted:(BOOL)inv
{
    [super init];
    self->data     = [aData copy];
    self->bytes    = (char *)[data bytes];
    self->inverted = inv;
    return self;
}

- (void)dealloc
{
    RELEASE(data);
    [super dealloc];
}

- (NSData *)bitmapRepresentation
{
    if (self->inverted) {
	char* theBytes = CallocAtomic(1, BITMAPDATABYTES);
	unsigned i;
	
	for (i = 0; i < BITMAPDATABYTES; i++)
	    theBytes[i] = ~bytes[i];
		
	return [NSData dataWithBytesNoCopy:theBytes length:BITMAPDATABYTES];
    }
    return data;
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
#if 1 /* see OGo bug #1594 */
    if (self->inverted) {
        return ISBITSET(self->bytes, aCharacter) ? NO : YES;
    }
    else {
        return ISBITSET(self->bytes, aCharacter);
    }
#else /* this is the original code, but it doesn't work (with gcc4?!) */
    return self->inverted ^ ISBITSET(self->bytes, aCharacter);
#endif
}

- (NSCharacterSet *)invertedSet
{
    return AUTORELEASE([[NSBitmapCharacterSet alloc]
                           initWithBitmapRepresentation:self->data
                           inverted:!self->inverted]);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else {
	id aData = [self bitmapRepresentation];
	return [[NSBitmapCharacterSet allocWithZone:zone]
		initWithBitmapRepresentation:aData];
    }
}

/* description */

- (NSString *)description
{
    NSMutableString *ms;
    unsigned int i;
    
    ms = [NSMutableString stringWithCapacity:128];
    [ms appendFormat:@"<0x%p[%@]: chars-in-latin1-range:",
        self, NSStringFromClass([self class])];

    for (i = 0; i < 256; i++) {
        if (ISBITSET(bytes, i))
            [ms appendFormat:@" %i", i];
    }

    if (self->inverted)
        [ms appendString:@" inverted"];
    
    [ms appendString:@">"];
    return ms;
}

@end /* NSBitmapCharacterSet */

/*
* NSMutableBitmapCharacterSet
*/

@implementation NSMutableBitmapCharacterSet

- (id)init
{
    [super init];
    self->data = [NSMutableData dataWithCapacity:BITMAPDATABYTES];
    self->bytes = (char*)[self->data bytes];
    return self;
}

- (id)initWithBitmapRepresentation:(id)aData
{
    return [self initWithBitmapRepresentation:aData inverted:NO];
}

- (id)initWithBitmapRepresentation:(id)aData inverted:(BOOL)inv
{
    if (aData == nil)
	return [self init];
    else {
	self->data = [aData mutableCopyWithZone:[self zone]];
	self->bytes = (char*)[self->data bytes];
	if (inv)
	    [self invert];
	return self;
    }
}

- (void)dealloc
{
    RELEASE(self->data);
    [super dealloc];
}

- (NSData *)bitmapRepresentation
{
    if (self->inverted) {
	char* theBytes = CallocAtomic(1, BITMAPDATABYTES);
	unsigned i;
	
	for (i = 0; i < BITMAPDATABYTES; i++)
	    theBytes[i] = ~bytes[i];
		
	return [NSData dataWithBytesNoCopy:theBytes length:BITMAPDATABYTES];
    }
    return self->data;
}

- (BOOL)characterIsMember:(unichar)aCharacter
{
    return inverted ^ ISBITSET(self->bytes, aCharacter);
}

- (NSCharacterSet *)invertedSet
{
    return AUTORELEASE([[NSBitmapCharacterSet alloc]
                           initWithBitmapRepresentation:self->data
                           inverted:!self->inverted]);
}

- (void)addCharactersInRange:(NSRange)aRange
{
    unsigned i;

    for (i = MIN(aRange.location+aRange.length-1, BITMAPDATABYTES);
         i >= aRange.location; i--) {
	if (self->inverted)
	    RESETBIT(self->bytes, i);
	else
	    SETBIT(self->bytes, i);
    }
}

- (void)addCharactersInString:(NSString *)aString
{
    int i;
    unichar c;
    
    for (i = ([aString length] - 1); i >= 0; i--) {
	c = [aString characterAtIndex:i];
	if (inverted)
	    RESETBIT(bytes, c);
	else
	    SETBIT(bytes, c);
    }
}

- (void)removeCharactersInRange:(NSRange)aRange
{
    unsigned i;

    for (i=MIN(aRange.location+aRange.length-1, BITMAPDATABYTES);
		    i >= aRange.location; i--)
	if (inverted)
	    SETBIT(bytes, i);
	else
	    RESETBIT(bytes, i);
}

- (void)removeCharactersInString:(NSString *)aString
{
    unsigned i;
    unichar c;
    
    for (i=[aString length]; i >= 0; i--) {
	c = [aString characterAtIndex:i];
	if (inverted)
	    SETBIT(bytes, c);
	else
	    RESETBIT(bytes, c);
    }
}

- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet
{
    id otherdata = [otherSet bitmapRepresentation];
    char* otherbytes = (char*)[otherdata bytes];
    unsigned i;
    
    if (inverted)
	for (i=0; i < BITMAPDATABYTES; i++)
	    bytes[i] |= ~otherbytes[i];
    else
	for (i=0; i < BITMAPDATABYTES; i++)
	    bytes[i] &= otherbytes[i];
}

- (void)formUnionWithCharacterSet:(NSCharacterSet *)otherSet
{
    id otherdata = [otherSet bitmapRepresentation];
    char* otherbytes = (char*)[otherdata bytes];
    unsigned i;
    
    if (inverted)
	for (i=0; i<BITMAPDATABYTES; i++)
	    bytes[i] &= ~otherbytes[i];
    else
	for (i=0; i<BITMAPDATABYTES; i++)
	    bytes[i] |= otherbytes[i];
}

- (void)invert
{
    inverted = !inverted;
}

@end /* NSMutableBitmapCharacterSet */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

