/*
 * Author: mircea
 */

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/NSCoder.h>
#include "NSConcreteNumber.h"

static Class NSStringClass = Nil;

static NSString *strValues[64] = {
   @"0",  @"1",  @"2",  @"3",  @"4",  @"5",  @"6",  @"7",  @"8",  @"9",
  @"10", @"11", @"12", @"13", @"14", @"15", @"16", @"17", @"18", @"19",
  @"20", @"21", @"22", @"23", @"24", @"25", @"26", @"27", @"28", @"29",
  @"30", @"31", @"32", @"33", @"34", @"35", @"36", @"37", @"38", @"39",
  @"40", @"41", @"42", @"43", @"44", @"45", @"46", @"47", @"48", @"49",
  @"50", @"51", @"52", @"53", @"54", @"55", @"56", @"57", @"58", @"59",
  @"60", @"61", @"62", @"63"
};
#define CHK_STATIC_STR \
  if (data >= 0 && data < 64) return strValues[(short)data];
#define CHK_STATIC_USTR \
  if (data < 64) return strValues[(short)data];

static char buf[256]; // THREAD
#define FMT_NUMSTR(__FMT__) \
    if (NSStringClass == Nil) NSStringClass = [NSString class];\
    sprintf(buf, __FMT__, data);\
    return [NSStringClass stringWithCString:buf];

@implementation NSBoolNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(BOOL*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    return data ? @"1" : @"0";
}

- (int)generality
{
    return 1;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (1 >= [otherNumber generality]) {
	BOOL other_data = [otherNumber boolValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(BOOL*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(BOOL);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSBoolNumber class] alloc]
		    initValue:&data withObjCType:@encode(BOOL)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(BOOL) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(BOOL) at:&data];
    return self;
}

@end /* NSBoolNumber */


@implementation NSCharNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(char*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%d");
}

- (int)generality
{
    return 2;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (2 >= [otherNumber generality]) {
	char other_data = [otherNumber charValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(char*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(char);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSCharNumber class] alloc]
		    initValue:&data withObjCType:@encode(char)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(char) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(char) at:&data];
    return self;
}

@end /* NSCharNumber */


@implementation NSUCharNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(unsigned char*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_USTR;
    FMT_NUMSTR("%d");
}

- (int)generality
{
    return 3;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (3 >= [otherNumber generality]) {
	unsigned char other_data = [otherNumber unsignedCharValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(unsigned char*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(unsigned char);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSUCharNumber class] alloc]
		    initValue:&data withObjCType:@encode(unsigned char)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(unsigned char) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(unsigned char) at:&data];
    return self;
}

@end /* NSUCharNumber */


@implementation NSShortNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(short*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%hd");
}

- (int)generality
{
    return 4;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (4 >= [otherNumber generality]) {
	short other_data = [otherNumber shortValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(short*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(short);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSShortNumber class] alloc]
		    initValue:&data withObjCType:@encode(short)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(short) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(short) at:&data];
    return self;
}

@end /* NSShortNumber */


@implementation NSUShortNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(unsigned short*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_USTR;
    FMT_NUMSTR("%hu");
}

- (int)generality
{
    return 5;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (5 >= [otherNumber generality]) {
	unsigned short other_data = [otherNumber unsignedShortValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(unsigned short*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(unsigned short);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSUShortNumber class] alloc]
		    initValue:&data withObjCType:@encode(unsigned short)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(unsigned short) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(unsigned short) at:&data];
    return self;
}

@end /* NSUShortNumber */


@implementation NSIntNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(int*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%d");
}

- (int)generality
{
    return 6;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (6 >= [otherNumber generality]) {
	int other_data = [otherNumber intValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(int*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(int);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSIntNumber class] alloc]
		    initValue:&data withObjCType:@encode(int)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(int) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(int) at:&data];
    return self;
}

@end /* NSIntNumber */


@implementation NSUIntNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(unsigned int*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%u");
}

- (int)generality
{
    return 7;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (7 >= [otherNumber generality]) {
	unsigned int other_data = [otherNumber unsignedIntValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(unsigned int*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(unsigned int);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSUIntNumber class] alloc]
		    initValue:&data withObjCType:@encode(unsigned int)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(unsigned int) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(unsigned int) at:&data];
    return self;
}

@end /* NSUIntNumber */


@implementation NSLongNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(long*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%ld");
}

- (int)generality
{
    return 8;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (8 >= [otherNumber generality]) {
	long other_data = [otherNumber longValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(long*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(long);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSLongNumber class] alloc]
		    initValue:&data withObjCType:@encode(long)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(long) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(long) at:&data];
    return self;
}

@end /* NSLongNumber */


@implementation NSULongNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(unsigned long*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%lu");
}

- (int)generality
{
    return 9;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (9 >= [otherNumber generality]) {
	unsigned long other_data = [otherNumber unsignedLongValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(unsigned long*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(unsigned long);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSULongNumber class] alloc]
		    initValue:&data withObjCType:@encode(unsigned long)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(unsigned long) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(unsigned long) at:&data];
    return self;
}

@end /* NSULongNumber */


@implementation NSLongLongNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(long long*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%lld");
}

- (int)generality
{
    return 10;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (10 >= [otherNumber generality]) {
	long long other_data = [otherNumber longLongValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(long long*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(long long);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSLongLongNumber class] alloc]
		    initValue:&data withObjCType:@encode(long long)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(long long) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(long long) at:&data];
    return self;
}

@end /* NSLongLongNumber */


@implementation NSULongLongNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(unsigned long long*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    CHK_STATIC_STR;
    FMT_NUMSTR("%llu");
}

- (int)generality
{
    return 11;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (11 >= [otherNumber generality]) {
	unsigned long long other_data = [otherNumber unsignedLongLongValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(unsigned long long*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(unsigned long long);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSULongLongNumber class] alloc]
		    initValue:&data withObjCType:@encode(unsigned long long)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(unsigned long long) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(unsigned long long) at:&data];
    return self;
}

@end /* NSULongLongNumber */


@implementation NSFloatNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(float*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    FMT_NUMSTR("%0.7g");
}

- (int)generality
{
    return 12;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (12 >= [otherNumber generality]) {
	float other_data = [otherNumber floatValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(float*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(float);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSFloatNumber class] alloc]
		    initValue:&data withObjCType:@encode(float)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(float) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(float) at:&data];
    return self;
}

@end /* NSFloatNumber */


@implementation NSDoubleNumber

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(double*)value;
    return self;
}

- (BOOL)boolValue
{
    return data;
}

- (signed char)charValue
{
    return data;
}

- (unsigned char)unsignedCharValue
{
    return data;
}

- (short)shortValue
{
    return data;
}

- (unsigned short)unsignedShortValue
{
    return data;
}

- (int)intValue
{
    return data;
}

- (unsigned int)unsignedIntValue
{
    return data;
}

- (long)longValue
{
    return data;
}

- (unsigned long)unsignedLongValue
{
    return data;
}

- (long long)longLongValue
{
    return data;
}

- (unsigned long long)unsignedLongLongValue
{
    return data;
}

- (float)floatValue
{
    return data;
}

- (double)doubleValue
{
    return data;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    FMT_NUMSTR("%0.16g");
}

- (int)generality
{
    return 13;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    if (13 >= [otherNumber generality]) {
	double other_data = [otherNumber doubleValue];

	if (data == other_data)
	    return NSOrderedSame;
	else
	    return (data < other_data) ?
		      NSOrderedAscending
		    : NSOrderedDescending;
    }
    else
	return [otherNumber compare:self];
}

// Override these from NSValue

- (void)getValue:(void*)value
{
    if (value == nil) {
	[[[InvalidArgumentException new]
		setReason:@"NULL buffer in -getValue"] raise];
    }
    else 
	*(double*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(double);
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NSDoubleNumber class] alloc]
		    initValue:&data withObjCType:@encode(double)];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(double) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(double) at:&data];
    return self;
}

@end /* NSDoubleNumber */

