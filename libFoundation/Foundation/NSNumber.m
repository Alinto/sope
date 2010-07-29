/* 
   NSNumber.m

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
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>

#include <Foundation/exceptions/NSValueExceptions.h>

#include <extensions/objc-runtime.h>

#include "NSConcreteNumber.h"
#include "NSConcreteValue.h"

/*
 * Temporary number used to allocate and initialize NSNumbers 
 * through initWith... methods in constructs like [[NSNumber alloc] initWith...
 */

@interface NSTemporaryNumber : NSNumber
@end

// THREAD
static NSNumber *boolYes  = nil;
static NSNumber *boolNo   = nil;
static NSNumber *intNums[64] = {
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil
};

#define INT_LRU_CACHE_SIZE 16
static short lastRecentlyUsed = 0;
static struct { int value; NSNumber *object; }
recentlyUsed[INT_LRU_CACHE_SIZE] = {
    { 0, nil }, { 0, nil }, { 0, nil }, { 0, nil },
    { 0, nil }, { 0, nil }, { 0, nil }, { 0, nil },
    { 0, nil }, { 0, nil }, { 0, nil }, { 0, nil },
    { 0, nil }, { 0, nil }, { 0, nil }, { 0, nil },
};

static inline void setupYesAndNo(void)
{
    if (boolYes == nil) {
        BOOL v;
        v = YES;
        boolYes = [[NSBoolNumber alloc] initValue:&v withObjCType:NULL];
    }
    if (boolNo == nil) {
        BOOL v;
        v = NO;
        boolNo = [[NSBoolNumber alloc] initValue:&v withObjCType:NULL];
    }
}
static inline NSIntNumber *makeInt(int i)
{
    static Class IntNumber = Nil;

    if (IntNumber == Nil) IntNumber = [NSIntNumber class];
    
    if ((i < 0) || (i > 63)) {
        /* scan LRU cache */
        register int p;

        for (p = 0; p < INT_LRU_CACHE_SIZE; p++) {
            if (recentlyUsed[p].value == i)
                return RETAIN(recentlyUsed[p].object);
        }
        
        lastRecentlyUsed++;
        if (lastRecentlyUsed == INT_LRU_CACHE_SIZE) lastRecentlyUsed = 0;
        
        RELEASE(recentlyUsed[lastRecentlyUsed].object);
        
        recentlyUsed[lastRecentlyUsed].value = i;
        recentlyUsed[lastRecentlyUsed].object =
            [[IntNumber alloc] initValue:&i withObjCType:NULL];
        
        return RETAIN(recentlyUsed[lastRecentlyUsed].object);
    }
    
    if (intNums[i] == nil)
        intNums[i] = [[IntNumber alloc] initValue:&i withObjCType:NULL];
    
    return RETAIN(intNums[i]);
}

@implementation NSTemporaryNumber

- (id)initWithBool:(BOOL)value
{
    (void)AUTORELEASE(self);
    setupYesAndNo();
    return value ? RETAIN(boolYes) : RETAIN(boolNo);
}

- (id)initWithChar:(signed char)value
{
    (void)AUTORELEASE(self);
    return [[NSCharNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedChar:(unsigned char)value
{
    (void)AUTORELEASE(self);
    return [[NSUCharNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithShort:(short)value
{
    (void)AUTORELEASE(self);
    return [[NSShortNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedShort:(unsigned short)value
{
    (void)AUTORELEASE(self);
    return [[NSUShortNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithInt:(int)value
{
    (void)AUTORELEASE(self);
    return makeInt(value);
}

- (id)initWithUnsignedInt:(unsigned int)value
{
    (void)AUTORELEASE(self);
    return [[NSUIntNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithLong:(long)value
{
    (void)AUTORELEASE(self);
    return [[NSLongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedLong:(unsigned long)value
{
    (void)AUTORELEASE(self);
    return [[NSULongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithLongLong:(long long)value
{
    (void)AUTORELEASE(self);
    return [[NSLongLongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedLongLong:(unsigned long long)value
{
    (void)AUTORELEASE(self);
    return [[NSULongLongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithFloat:(float)value
{
    (void)AUTORELEASE(self);
    return [[NSFloatNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithDouble:(double)value
{
    (void)AUTORELEASE(self);
    return [[NSDoubleNumber alloc] initValue:&value withObjCType:NULL];
}

@end

/*
 *  NSNumber class implementation
 */

@implementation NSNumber

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject((self == [NSNumber class])
                            ? [NSTemporaryNumber class] : (Class)self,
                            0, zone);
}

/*
 * Determines the concrete value class
 * Only numbers
 */

+ (Class)concreteClassForObjCType:(const char*)type
{
    if (!type)
[[[NSNumberException new] setReason:@"NULL type"] raise];

    if (Strlen(type) == 1) {
	switch(*type) {
        case _C_CHR:	return [NSCharNumber      class];
        case _C_UCHR:	return [NSUCharNumber     class];
        case _C_SHT:	return [NSShortNumber     class];
        case _C_USHT:	return [NSUShortNumber    class];
        case _C_INT:	return [NSIntNumber       class];
        case _C_UINT:	return [NSUIntNumber      class];
        case _C_LNG:	return [NSLongNumber      class];
        case _C_ULNG:	return [NSULongNumber     class];
        case _C_FLT:	return [NSFloatNumber     class];
        case _C_DBL:	return [NSDoubleNumber    class];
        case 'q':	return [NSLongLongNumber  class];
        case 'Q':	return [NSULongLongNumber class];
	}
    }

    if (self == [NSNumber class]) {
	[[[NSNumberException new]
                  initWithFormat:@"Invalid number type '%s'", type] raise];

	return nil;
    }
    else 
	return [super concreteClassForObjCType:type];
}

+ (NSNumber*)numberWithBool:(BOOL)value
{
    setupYesAndNo();
    return value ? boolYes : boolNo;
}

+ (NSNumber*)numberWithChar:(signed char)value
{
    return AUTORELEASE([[NSCharNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithUnsignedChar:(unsigned char)value
{
    return AUTORELEASE([[NSUCharNumber alloc] 
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithShort:(short)value
{
    return AUTORELEASE([[NSShortNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithUnsignedShort:(unsigned short)value
{
    return AUTORELEASE([[NSUShortNumber alloc] 
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithInt:(int)value
{
    return AUTORELEASE(makeInt(value));
}

+ (NSNumber*)numberWithUnsignedInt:(unsigned int)value
{
    return AUTORELEASE([[NSUIntNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithLong:(long)value
{
    return AUTORELEASE([[NSLongNumber alloc] 
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithUnsignedLong:(unsigned long)value
{
    return AUTORELEASE([[NSULongNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithLongLong:(long long)value
{
    return AUTORELEASE([[NSLongLongNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithUnsignedLongLong:(unsigned long long)value
{
    return AUTORELEASE([[NSULongLongNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithFloat:(float)value
{
    return AUTORELEASE([[NSFloatNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

+ (NSNumber*)numberWithDouble:(double)value
{
    return AUTORELEASE([[NSDoubleNumber alloc]
                           initValue:&value withObjCType:NULL]);
}

- (id)initWithBool:(BOOL)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithChar:(signed char)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithUnsignedChar:(unsigned char)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithShort:(short)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithUnsignedShort:(unsigned short)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithInt:(int)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithUnsignedInt:(unsigned int)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithLong:(long)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithUnsignedLong:(unsigned long)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithLongLong:(long long)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithUnsignedLongLong:(unsigned long long)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithFloat:(float)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)initWithDouble:(double)value
{
    [self shouldNotImplement:_cmd];
    return nil;
}

/* These methods are not written in concrete subclassses */

- (unsigned)hash
{
    return [self unsignedIntValue];
}

- (NSComparisonResult)compare:(NSNumber*)otherNumber
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (BOOL)isEqualToNumber:(NSNumber*)aNumber
{
    return [self compare:aNumber] == NSOrderedSame;
}

- (BOOL)isEqual:aNumber
{
    return [aNumber isKindOfClass:[NSNumber class]] 
        && [self isEqualToNumber:aNumber];
}

- (NSString*)description
{
    return [self descriptionWithLocale:nil];
}

- (NSString*)descriptionWithLocale:(NSDictionary*)locale
{
    [self subclassResponsibility:_cmd];
    return nil;
}

/* Access methods are implemented in concrete subclasses */

- (BOOL)boolValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (signed char)charValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned char)unsignedCharValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (short)shortValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned short)unsignedShortValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (int)intValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned int)unsignedIntValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (long)longValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned long)unsignedLongValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (long long)longLongValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned long long)unsignedLongLongValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (float)floatValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (double)doubleValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (NSString *)stringValue
{
    return [self descriptionWithLocale:nil];
}

@end /* NSNumber */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
