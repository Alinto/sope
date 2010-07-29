#!/bin/sh

echo "THIS SCRIPT IS DEPRECATED!"
exit 10

template ()
{
NAME=$1
C=$2
METHOD=$3
FORMAT=$4
GENERALITY=$5

cat <<EOF

/*
 *  DO NOT EDIT! GENERATED AUTOMATICALLY FROM NSConcreteNumber.m.sh.
 *  ${NAME} concrete number
 */

@implementation NS${NAME}Number

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject (self, 0, zone);
}

- initValue:(const void*)value withObjCType:(const char*)type;
{
    self = [super init];
    data = *(${C}*)value;
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
    if (NSStringClass == Nil) NSStringClass = [NSString class];
    return [NSStringClass stringWithFormat:@${FORMAT}, data];
}

- (int)generality
{
    return ${GENERALITY};
}

- (NSComparisonResult)compare:(NSNumber*)otherNumber
{
    if([self generality] >= [otherNumber generality]) {
	${C} other_data = [otherNumber ${METHOD}Value];

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
	*(${C}*)value = data;
}
- (void *)valueBytes
{
    return &(self->data);
}

- (const char*)objCType
{
    return @encode(${C});
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    else
	return [[[NS${NAME}Number class] alloc]
		    initValue:&data withObjCType:@encode(${C})];
}

// NSCoding

- (Class)classForCoder
{
    return isa;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeValueOfObjCType:@encode(${C}) at:&data];
}

- (id)initWithCoder:(NSCoder*)coder
{
    [coder decodeValueOfObjCType:@encode(${C}) at:&data];
    return self;
}

@end /* NS${NAME}Number */

EOF
}

#
# Generate common part
#

cat <<EOF
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

EOF

template Bool	"BOOL"		bool		'"%d"'		1
template Char	"char"		char		'"%d"'		2
template UChar	"unsigned char"	unsignedChar	'"%d"'		3
template Short	"short"		short		'"%hd"'		4
template UShort	"unsigned short" unsignedShort	'"%hu"'		5
template Int	"int"		int		'"%d"'		6
template UInt	"unsigned int"	unsignedInt	'"%u"'		7
template Long	"long"		long		'"%ld"'		8
template ULong	"unsigned long"	unsignedLong	'"%lu"'		9
template LongLong "long long"	longLong	'"%lld"'	10
template ULongLong "unsigned long long"	unsignedLongLong '"%llu"' 11
template Float	"float"		float		'"%0.7g"'	12
template Double	"double"	double		'"%0.16g"'	13
