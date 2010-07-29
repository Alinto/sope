/* 
   NSCharacterSet.m

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
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSBundle.h>

#include <Foundation/exceptions/GeneralExceptions.h>

#include "NSConcreteCharacterSet.h"

@implementation NSCharacterSet

// Cluster allocation

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject( (self == [NSCharacterSet class]) ? 
			     [NSBitmapCharacterSet class] : (Class)self,
			     0, zone);
}

// Creating a shared Character Set from a standard file
// We should mmap only ONE file and have a the sets initialized
// with range subdata of the main file (range subdata of NSData must
// not copy its data but retain its master data ...
// In this case we need a dictionary to know the offset of each charset
// in the BIG data; this approach should be very efficient on systems
// that support mmap (in paged virtual memory systems)

static NSMutableDictionary* predefinedCharacterSets = nil;

extern NSRecursiveLock* libFoundationLock;

+ (NSCharacterSet *)characterSetWithContentsOfFile:(NSString *)fileName
{
    /*
      Note: we need to be careful here, this has potential for
            endless recursion!
    */
    NSCharacterSet *aSet;
    
    if (fileName == nil)
	return nil;
    
    [libFoundationLock lock];
    {
        if (predefinedCharacterSets == nil) {
	    predefinedCharacterSets =
                [[NSMutableDictionary alloc] initWithCapacity:12];
        }
        aSet = [predefinedCharacterSets objectForKey:fileName];
    }
    [libFoundationLock unlock];

    if (aSet == nil) {
	NSString *fullFilenamePath;
	id data = nil;
	
	fullFilenamePath = [NSBundle _fileResourceNamed:fileName
				     extension:@"bitmap"
				     inDirectory:@"CharacterSets"];
	
	if (fullFilenamePath != nil)
	    data = [NSData dataWithContentsOfMappedFile:fullFilenamePath];

	if (data == nil) {
	    /* Note: yes, this is weird, but matches Panther! */
	    data = [NSData data];
	}
        
	aSet = AUTORELEASE([[NSBitmapCharacterSet alloc] 
                               initWithBitmapRepresentation:data]);
        if (aSet == nil) {
	    fprintf(stderr, 
		    "ERROR(%s): could not create character set for "
		    "data (0x%p,len=%d) from file %s (%s)\n",
		    __PRETTY_FUNCTION__,
		    data, [data length], [fileName cString],
		    [fullFilenamePath cString]);
        }
        
        [libFoundationLock lock];
	[predefinedCharacterSets setObject:aSet forKey:fileName];
        [libFoundationLock unlock];
    }

    return aSet;
}

// Creating a Standard Character Set 

+ (NSCharacterSet*)alphanumericCharacterSet
{
    return [self characterSetWithContentsOfFile:@"alphanumericCharacterSet"];
}

+ (NSCharacterSet*)controlCharacterSet
{
    return [self characterSetWithContentsOfFile:@"controlCharacterSet"];
}

+ (NSCharacterSet*)decimalDigitCharacterSet
{
    return [self characterSetWithContentsOfFile:@"decimalDigitCharacterSet"];
}

+ (NSCharacterSet*)decomposableCharacterSet
{
    return [self characterSetWithContentsOfFile:@"decomposableCharacterSet"];
}

+ (NSCharacterSet*)illegalCharacterSet
{
    return [self characterSetWithContentsOfFile:@"illegalCharacterSet"];
}

+ (NSCharacterSet*)letterCharacterSet
{
    return [self characterSetWithContentsOfFile:@"letterCharacterSet"];
}

+ (NSCharacterSet*)lowercaseLetterCharacterSet
{
    return [self characterSetWithContentsOfFile:@"lowercaseLetterCharacterSet"];
}

+ (NSCharacterSet*)nonBaseCharacterSet
{
    return [self characterSetWithContentsOfFile:@"nonBaseCharacterSet"];
}

+ (NSCharacterSet*)uppercaseLetterCharacterSet
{
    return [self characterSetWithContentsOfFile:@"uppercaseLetterCharacterSet"];
}

+ (NSCharacterSet*)whitespaceAndNewlineCharacterSet
{
    return [self characterSetWithContentsOfFile:@"whitespaceAndNewlineCharacterSet"];
}

+ (NSCharacterSet*)whitespaceCharacterSet
{
    return [self characterSetWithContentsOfFile:@"whitespaceCharacterSet"];
}

+ (NSCharacterSet*)punctuationCharacterSet
{
    return [self characterSetWithContentsOfFile:@"punctuationCharacterSet"];
}

+ (NSCharacterSet*)emptyCharacterSet
{
    return [self characterSetWithContentsOfFile:@"emptyCharacterSet"];
}

// Creating a Custom Character Set 

+ (NSCharacterSet*)characterSetWithBitmapRepresentation:(NSData*)data
{
    return AUTORELEASE([[NSBitmapCharacterSet alloc] 
                           initWithBitmapRepresentation:data]);
}

+ (NSCharacterSet*)characterSetWithCharactersInString:(NSString *)aString
{
    unsigned char *bytes = CallocAtomic(1, BITMAPDATABYTES);
    id	          data;
    unsigned int  i, count;

    for (i = 0, count = [aString length]; i < count; i++) {
        register unichar c;
        
        c = [aString characterAtIndex:i];
        SETBIT(bytes, c);
    }
    
    data = [[NSData alloc] initWithBytesNoCopy:bytes 
                           length:BITMAPDATABYTES];
    self = [self isKindOfClass:[NSMutableCharacterSet class]]
        ? AUTORELEASE([[NSMutableBitmapCharacterSet alloc] 
                          initWithBitmapRepresentation:data])
        : AUTORELEASE([[NSBitmapCharacterSet alloc] 
                          initWithBitmapRepresentation:data]);
    [data release];
    return self;
}

+ (NSCharacterSet*)characterSetWithRange:(NSRange)aRange
{
    return AUTORELEASE([[NSRangeCharacterSet alloc] initWithRange:aRange]);
}

// Getting a Binary Representation 

- (NSData*)bitmapRepresentation
{
    [self subclassResponsibility:_cmd];
    return nil;
}

// Testing Set Membership 

- (BOOL)characterIsMember:(unichar)aCharacter
{
    [self subclassResponsibility:_cmd];
    return NO;
}

// Inverting a Character Set 

- (NSCharacterSet*)invertedSet
{
    [self subclassResponsibility:_cmd];
    return nil;
}

// NSCopying

- copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	    return RETAIN(self);
    else {
	    id data = [self bitmapRepresentation];
	    return [[NSCharacterSet alloc] initWithBitmapRepresentation:data];
    }
}

- mutableCopyWithZone:(NSZone*)zone
{
    id data = [self bitmapRepresentation];
    return RETAIN([NSMutableCharacterSet
                      characterSetWithBitmapRepresentation:data]);
}

// NSArchiving

- (Class)classForCoder
{
    return [NSCharacterSet class];
}

- (id)replacementObjectForCoder:(NSCoder*)coder
{
    if ([[self class] isKindOfClass:[NSMutableCharacterSet class]])
	return [super replacementObjectForCoder:coder];
    return self;
}

- initWithCoder:(NSCoder*)coder
{
    id data;
    id new;

    [coder decodeValueOfObjCType:@encode(id) at:&data];
    new = [[[self class] alloc] initWithBitmapRepresentation:data];
    [self dealloc];
    return new;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    id data = [self bitmapRepresentation];
    [coder encodeValueOfObjCType:@encode(id) at:&data];
}

@end /* NSCharacterSet */

@implementation NSMutableCharacterSet

// Cluster allocation

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject( (self == [NSMutableCharacterSet class])
			     ? [NSMutableBitmapCharacterSet class] 
			     : (Class)self, 0, zone);
}

// Creating a Custom Character Set 

+ (NSCharacterSet*)characterSetWithBitmapRepresentation:(NSData*)data
{
    return AUTORELEASE([[self alloc] initWithBitmapRepresentation:data]);
}

+ (NSCharacterSet *)characterSetWithContentsOfFile:(NSString *)fileName
{
    NSCharacterSet *set = [super characterSetWithContentsOfFile:fileName];
    return AUTORELEASE([set mutableCopy]);
}
+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)aString
{
    NSCharacterSet *set = [super characterSetWithCharactersInString:aString];
    return AUTORELEASE([set mutableCopy]);
}
+ (NSCharacterSet*)characterSetWithRange:(NSRange)aRange
{
    NSCharacterSet *set = [super characterSetWithRange:aRange];
    return AUTORELEASE([set mutableCopy]);
}

// Adding and Removing Characters

- (void)addCharactersInRange:(NSRange)aRange
{
    [self subclassResponsibility:_cmd];
}

- (void)addCharactersInString:(NSString*)aString
{
    [self subclassResponsibility:_cmd];
}

- (void)removeCharactersInRange:(NSRange)aRange
{
    [self subclassResponsibility:_cmd];
}

- (void)removeCharactersInString:(NSString*)aString
{
    [self subclassResponsibility:_cmd];
}

// Combining Character Sets

- (void)formIntersectionWithCharacterSet:(NSCharacterSet*)otherSet
{
    [self subclassResponsibility:_cmd];
}

- (void)formUnionWithCharacterSet:(NSCharacterSet*)otherSet
{
    [self subclassResponsibility:_cmd];
}

// Inverting a Character Set

- (void)invert
{
    [self subclassResponsibility:_cmd];
}

// NSCopying

- copyWithZone:(NSZone*)zone
{
    id data = [self bitmapRepresentation];
    return RETAIN([NSCharacterSet characterSetWithBitmapRepresentation:data]);
}

// NSArchiving

- (Class)classForCoder
{
    return [NSMutableCharacterSet class];
}

@end /* NSMutableCharacterSet */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

