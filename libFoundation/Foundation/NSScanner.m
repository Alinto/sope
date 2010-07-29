/* 
   NSScanner.m

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
#include <Foundation/NSString.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSRange.h>
#include "NSConcreteScanner.h"

/* BUGS:

   The current implementation assumes that the characters given in
   the locale dictionary under the NSDecimalDigits key are consecutive.

   No verify is performed to see if the thousand separator is positioned
   strictly between groups of digits. Maybe the grouping of digits should be
   also described in the locale dictionary.
*/

@implementation NSScanner

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject([NSConcreteScanner class], 0, zone);
}

+ (id)scannerWithString:(NSString*)string
{
    NSScanner* scanner = AUTORELEASE([[NSConcreteScanner alloc]
                                         initWithString:string]);
    [scanner setCharactersToBeSkipped:
                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return scanner;
}

+ (id)localizedScannerWithString:(NSString*)string
{
    NSScanner* scanner = [self scannerWithString:string];
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

    [dictionary setObject:[userDefaults objectForKey:NSDecimalDigits]
		forKey:NSDecimalDigits];
    [dictionary setObject:[userDefaults objectForKey:NSDecimalSeparator]
		forKey:NSDecimalSeparator];
    [dictionary setObject:[userDefaults objectForKey:NSThousandsSeparator]
		forKey:NSThousandsSeparator];

    return scanner;
}

- (id)initWithString:(NSString*)string
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSString*)string
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (void)setScanLocation:(unsigned int)index
{
    [self subclassResponsibility:_cmd];
}

- (unsigned int)scanLocation
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (void)setCaseSensitive:(BOOL)flag
{
    [self subclassResponsibility:_cmd];
}

- (BOOL)caseSensitive
{
    [self subclassResponsibility:_cmd];
    return NO;
}

- (void)setCharactersToBeSkipped:(NSCharacterSet *)skipSet
{
    [self subclassResponsibility:_cmd];
}

- (NSCharacterSet *)charactersToBeSkipped
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (BOOL)scanCharactersFromSet:(NSCharacterSet *)scanSet
  intoString:(NSString **)value
{
    NSString       *string;
    unsigned int   orig;
    unsigned int   length;
    unsigned int   location;
    NSCharacterSet *lSkipSet;

    string   = [self string];
    orig     = [self scanLocation];
    length   = [string length];
    location = orig;
    
    lSkipSet = [self charactersToBeSkipped];
    
    if (![lSkipSet isEqual:scanSet]) {
        /* scan characters */
        
        for (; location < length; location++) {
            if (![lSkipSet characterIsMember:[string characterAtIndex:location]])
                break;
        }
        [self setScanLocation:location];
        orig = location;
    }
    
    for (; location < length; location++) {
	if (![scanSet characterIsMember:[string characterAtIndex:location]])
	    break;
    }

    /* Check if we scanned anything */
    if (location != orig) {
	if (value) {
	    NSRange range = { orig, location - orig }; 
	    *value = [string substringWithRange:range];
	}
	[self setScanLocation:location];
	return YES;
    }

    return NO;
}

- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet*)stopSet
  intoString:(NSString**)value
{
    return [self scanCharactersFromSet:[stopSet invertedSet] intoString:value];
}

- (BOOL)scanDouble:(double*)value
{
#define DOUBLE_TYPE
# include "scanFloat.def"
#undef DOUBLE_TYPE
}

- (BOOL)scanFloat:(float*)value
{
#define FLOAT_TYPE
# include "scanFloat.def"
#undef FLOAT_TYPE
}

- (BOOL)scanInt:(int*)value
{
#define INT_TYPE
# include "scanInt.def"
#undef INT_TYPE
}

- (BOOL)scanLongLong:(long long*)value
{
#define LONG_LONG_TYPE
# include "scanInt.def"
#undef LONG_LONG_TYPE
}

- (BOOL)scanString:(NSString*)searchString intoString:(NSString**)value
{
    id string = [self string];
    unsigned int searchStringLength = [searchString length];
    NSRange range;
    unsigned int options;
    unsigned int location;

    /* First skip the blank characters */
    [self scanCharactersFromSet:[self charactersToBeSkipped] intoString:NULL];

    range.location = location = [self scanLocation];
    range.length = searchStringLength;

    /* Check if the searchString can be contained in the remained scanned
       string. */
    if ([string length] < range.location + range.length)
	return NO;

    options = NSAnchoredSearch;
    if (![self caseSensitive])
	options |= NSCaseInsensitiveSearch;

    if ([string compare:searchString options:options range:range]
	    == NSOrderedSame) {
	[self setScanLocation:(range.location + range.length)];
	if (value)
	    *value = [searchString copy];
	return YES;
    }

    return NO;
}

- (BOOL)scanUpToString:(NSString*)stopString intoString:(NSString**)value
{
    id string = [self string];
    int length = [string length];
    NSRange range, lastRange;
    unsigned int options = 0;
    unsigned int location;

    /* First skip the blank characters */
    [self scanCharactersFromSet:[self charactersToBeSkipped] intoString:NULL];

    if (![self caseSensitive])
	options = NSCaseInsensitiveSearch;

    range.location = location = [self scanLocation];
    range.length = length - location;
    lastRange = range;
    range = [string rangeOfString:stopString options:options range:range];

    if (range.length) {
	/* A match was found */
	[self setScanLocation:range.location];
	if (value) {
	    range.length = range.location - location;
	    range.location = location;
	    *value = [string substringWithRange:range];
	}
	return YES;
    }
    else {
        /* Return the remaining of the string as the result of scanning */
        [self setScanLocation:length];
        if (value)
            *value = [string substringWithRange:lastRange];
        return lastRange.length > 0;
    }

    return NO;
}

- (BOOL)isAtEnd
{
    return [self scanLocation] == [[self string] length];
}

- (void)setLocale:(NSDictionary*)locale
{
    [self subclassResponsibility:_cmd];
}

- (NSDictionary*)locale
{
    [self subclassResponsibility:_cmd];
    return nil;
}


@end /* NSScanner */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
