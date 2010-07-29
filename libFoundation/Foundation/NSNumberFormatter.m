 /* 
   NSNumberFormatter.m

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Martin Spindler (ms@mdlink.de), Helge Hess (helge@mdlink.de)

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
// $Id: NSNumberFormatter.m 1319 2006-07-14 13:06:21Z helge $

#include <ctype.h>
#include <Foundation/common.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/NSNumberFormatter.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>

/*
  Missing:
  zero format strings
 */

#define posDefaultFormat @"0.00"
#define negDefaultFormat @"-0.00"

static void     _checkFormat(NSNumberFormatter *self, NSString *_format);
static unichar  separatorFromString(NSString *_string);

static NSString *_prefix(NSNumberFormatter *self, NSString *_format);
static NSString *_suffix(NSNumberFormatter *self, NSString *_format);
static NSString *cleanFormat(NSNumberFormatter *self, NSString *_format);
static NSString *digitsToDot(NSString *_string);
static NSString *digitsFromDot(NSString *_string, NSString *_sep);

static BOOL digitsForString(NSNumberFormatter *self,
                            NSString **digitStr, NSString *_string);

static BOOL checkMinMaxForNumber(NSNumberFormatter *self, NSNumber *_number);

#if defined(__MINGW32__)
static inline const char *index(const char *cstr, char c) {
    if (cstr == NULL) return NULL;
    while (*cstr) {
        if (*cstr == c) return cstr;
        cstr++;
    }
    return NULL;
}
#endif

@implementation NSNumberFormatter

- (id)init
{
    self->decimalSeparator  = '.';
    self->thousandSeparator = ',';
    return self;
}

- (void)dealloc
{
    RELEASE(self->negativeFormat);
    RELEASE(self->positiveFormat);
    RELEASE(self->maximum);
    RELEASE(self->minimum);
    [super dealloc];
}

// accessors

- (void)setFormat:(NSString *)_format
{
    NSArray *stringArray;
    
    if ([_format length] == 0) {
        [self setPositiveFormat:nil];
        [self setNegativeFormat:nil];
        return;
    }

    //TODO: insert zeroFormat
    stringArray = [_format componentsSeparatedByString:@";"];
    
    switch ([stringArray count]) {
        case 0:
            [self setPositiveFormat:nil];
            [self setNegativeFormat:nil];
            break;
        case 1:
            [self setPositiveFormat:_format];
            [self setNegativeFormat:[@"-" stringByAppendingString:_format]];
            break;
        case 2:
            [self setPositiveFormat:[stringArray objectAtIndex:0]];
            [self setNegativeFormat:[stringArray objectAtIndex:1]];
            break;
        case 3:
            //TODO: insert zeroFormat (at index 1)
            //NSLog(@"WARNING: zero format is not supported !");
            [self setPositiveFormat:[stringArray objectAtIndex:0]];
            [self setNegativeFormat:[stringArray objectAtIndex:2]];
            break;
        case 4:
            //TODO: insert zeroFormat (at index 1)
            //NSLog(@"WARNING: zero format is not supported !");
            [self setPositiveFormat:[stringArray objectAtIndex:0]];
            [self setNegativeFormat:[stringArray objectAtIndex:2]];
            [self setDecimalSeparator:[stringArray objectAtIndex:3]];
            break;
        case 5:
            //TODO: insert zeroFormat (at index 1)
            //NSLog(@"WARNING: zero format is not supported !");
            [self setPositiveFormat:[stringArray objectAtIndex:0]];
            [self setNegativeFormat:[stringArray objectAtIndex:2]];
            [self setDecimalSeparator:[stringArray objectAtIndex:3]];
            [self setThousandSeparator:[stringArray objectAtIndex:4]];
            break;
        default:
            [[[InvalidArgumentException alloc]
                 initWithReason:@"invalid format passed to -setFormat:"] raise];
            break;
    }
}

- (NSString *)format
{
    NSMutableString *myString = nil;

    myString = [NSMutableString stringWithString:[self positiveFormat]];
    [myString appendString:@";"];
    [myString appendString:[self negativeFormat]];
    return myString;
}

- (void)setNegativeFormat:(NSString *)_format
{
    _checkFormat(self, _format);

    if (self->negativeFormat != _format) {
        RELEASE(self->negativeFormat);
        self->negativeFormat = [_format copyWithZone:[self zone]];
    }
}
- (NSString *)negativeFormat
{
    return self->negativeFormat != nil
	? self->negativeFormat : (NSString *)negDefaultFormat;
}

- (void)setPositiveFormat:(NSString *)_format
{
    _checkFormat(self, _format);

    if (self->positiveFormat != _format) {
        RELEASE(self->positiveFormat); self->positiveFormat = nil;
        self->positiveFormat = [_format copyWithZone:[self zone]];
    }
}
- (NSString *)positiveFormat
{
    return self->positiveFormat
	? self->positiveFormat : (NSString *)posDefaultFormat;
}
- (NSString *)zeroFormat
{
    return [self positiveFormat];
}

- (void)setDecimalSeparator:(NSString *)_separator
{
    self->decimalSeparator = separatorFromString(_separator);
}
- (NSString *)decimalSeparator
{
    char c = self->decimalSeparator;
    if (c == '.') return @".";
    if (c == ',') return @",";
    return [NSString stringWithCString:&c length:1];
}

- (void)setThousandSeparator:(NSString *)_separator
{
    self->thousandSeparator = separatorFromString(_separator);
}
- (NSString *)thousandSeparator
{
    char c = self->thousandSeparator;
    if (c == '.') return @".";
    if (c == ',') return @",";
    return [NSString stringWithCString:&c length:1];
}

- (void)setMinimum:(NSNumber *)_number
{
    ASSIGN(self->minimum, _number);
}
- (NSNumber *)minimum
{
    return self->minimum;
}

- (void)setMaximum:(NSNumber *)_number
{
    ASSIGN(self->maximum, _number);
}
- (NSNumber *)maximum
{
    return self->maximum;
}

- (void)setHasThousandSeparators:(BOOL)_status
{
    self->hasThousandSeparator = _status;
}
- (BOOL)hasThousandSeparators
{
    return self->hasThousandSeparator;
}

- (void)setAllowsFloats:(BOOL)_flag
{
    [self notImplemented:_cmd];
}
- (BOOL)allowsFloats
{
    return YES;
}

// public methods

- (NSString *)_stringForDecimalNumber:(id)anObject
{
    return [self stringForObjectValue:
                   [NSNumber numberWithDouble:[anObject doubleValue]]];
}

- (NSString *)stringForObjectValue:(id)anObject
{
    static Class DecNumber = Nil;
    BOOL             hasThousandSep, hasDecimalSep;
    NSString         *format;
    NSString         *numStr;
    NSMutableString  *newString;
    int              len;
    unsigned         decSepIdx;
    double           dblValue;
    NSString         *cFmt;
    NSString         *decSepFmt;

    //NSLog(@"STRING FOR OBJECT: %@", anObject);
    
    if (DecNumber == Nil)
        DecNumber = NSClassFromString(@"NSDecimalNumber");
    
    if ([anObject isKindOfClass:DecNumber])
        return [self _stringForDecimalNumber:anObject];
    
    if (anObject == nil) anObject = [NSNumber numberWithDouble:0.0];
    
    if ([anObject isKindOfClass:[NSString class]])
        return anObject;
    
    if (![anObject isKindOfClass:[NSNumber class]]) {
        [[[InvalidArgumentException alloc]
             initWithReason:@"number formatter formats only numbers !"] raise];
        return nil;
    }

    dblValue = [anObject doubleValue];

    if (dblValue < 0.0)
        format = [self negativeFormat];
    else if (dblValue == 0.0)
        format = [self zeroFormat];
    else
        format = [self positiveFormat];
    
    if ([format length] == 0) {
        /* no format given, return stringValue */
        //NSLog(@"%s: missing format ..", __PRETTY_FUNCTION__);
        return [anObject stringValue];
    }
    
    /* generate proper C format */
    
    cFmt = @"%0.16g";
    
    decSepIdx     = [format indexOfString:[self decimalSeparator]];
    hasDecimalSep = (decSepIdx != NSNotFound) ? YES : NO;
    
    if (hasDecimalSep) {
        /* get format part behind the decimal separator .. */
        decSepFmt = digitsFromDot(format, [self decimalSeparator]);
        cFmt = [NSString stringWithFormat:@"%%0.%if", [decSepFmt length]];
    }
    else
        decSepFmt = nil;
    
    numStr = [NSString stringWithFormat:cFmt, dblValue];
    
    //NSLog(@"USE NUM STRING: %@ (fmt='%@')", numStr, cFmt);
    
    /* removes minus sign in result if negative .. */
    
    if (dblValue < 0.0)
        numStr = [numStr substringFromIndex:1];
    
    /* scan whether the format contains thousand separators */
    {
        register const unsigned char *cfmt;
        hasThousandSep = NO;
        if ((cfmt = (const unsigned char *)[format cString]) != NULL) {
            for ( ; *cfmt != '\0' && !hasThousandSep; cfmt++) {
                if (*cfmt == self->thousandSeparator)
                    hasThousandSep = YES;
            }
        }
    }
    //hasThousandSep=index([format cString], self->thousandSeparator) ? YES : NO;
    
    // removes all '#' and the 1000separators
    format = cleanFormat(self, format);
    NSAssert(format, @"invalid state !");
    
    //Digits in front of Decimal Separator
    newString = [digitsToDot(numStr) mutableCopy];
    newString = AUTORELEASE(newString);

    /* insert thousand separators .. */
    
    if (self->hasThousandSeparator || hasThousandSep) {
        int length = [newString length];
        int i = 1;
        
        while ((i * 3) < length) {
            [newString insertString:[self thousandSeparator]
                       atIndex:(length - i * 3)];
            i++;
        }
    }
    len = [digitsToDot(format) length] - [digitsToDot(numStr) length];
    if (len > 0) {
        [newString insertString:[digitsToDot(format) substringToIndex:len]
                   atIndex:0];
    }
    
    /* add format prefix in front ... */
    
    [newString insertString:_prefix(self, format) atIndex:0];
    
    /* Digits behind Decimal Separator */
    
    if (hasDecimalSep && [self allowsFloats]) {
        NSString *nkNumStr;
        unsigned padLen;
            
        /* add separator */
        [newString appendString:[self decimalSeparator]];
        
        /* get digits after decimal point */
        nkNumStr = digitsFromDot(numStr, @".");
        
        /* find out whether format is longer than value .. */
        padLen = [decSepFmt length] - [nkNumStr length];
            
        if (padLen > 0) {
            /* format is longer than value, pad the rest */
            NSString *fmtValue;
            unsigned idx;
                
            idx      = [decSepFmt length] - padLen;
            fmtValue = [decSepFmt substringFromIndex:idx];
                
            [newString appendString:nkNumStr];
            [newString appendString:fmtValue];
        }
        else if (padLen == 0) {
            /* perfect match */
            [newString appendString:nkNumStr];
        }
        else {
            /* value string is longer than format .. */
            NSString *value;
                
            value = [nkNumStr substringToIndex:[nkNumStr length]];
            [newString appendString:value];
        }
    }
    
    /* add format suffix */
    [newString appendString:_suffix(self, format)];
    
    return newString;
}


- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string
  errorDescription:(NSString **)error
{
    NSString *num = nil;
    BOOL     status;
    
    NSAssert(self->thousandSeparator != self->decimalSeparator,
             @"decimal and thousand separators are equal !");
    
    if (digitsForString(self, &num, string)) {
        status = YES;
        if (obj)   *obj   = [NSNumber numberWithDouble:[num doubleValue]];
        if (error) *error = @"";
    }
    else {
        status = NO;
        if (obj)   *obj   = [NSNumber numberWithDouble:[num doubleValue]];
        if (error) *error = @"wrong chars in number (only digits and sep's) !";
    }

    if (!checkMinMaxForNumber(self, *obj)) {
        status = NO;
        if (obj)   *obj   = nil;
        if (error) *error = @"number isn't in range of min and max! ";
    }
    return status;
} 

- (BOOL)isPartialStringValid:(NSString *)partialString
  newEditingString:(NSString **)newString
  errorDescription:(NSString **)error
{
    NSString *str     = nil;
    NSNumber *num     = nil;
    BOOL     status;

    *error = @"";

    //TODO: modify *newString (maybe it's not necessary)
    if (digitsForString(self, &str, partialString)) {
        status = YES;
    }
    else {
        status  = NO;
        if (error) *error = @"wrong chars in number (only digits and sep's) !";
        if (newString) *newString = str;
    }
    
    num = [NSNumber numberWithDouble:[str doubleValue]];
    if (!checkMinMaxForNumber(self, num)) {
        status  = NO;
        num     = nil;
        if (error) *error = @"number isn't in range of min and max! ";
    }
    return YES;
}


// Private Methods

static void _checkFormat(NSNumberFormatter *self, NSString *_format)
{
    char *format     = NULL;
    BOOL digitStatus = NO;
    int  decSepCount = 0; 
    int  i           = 0;
    
    if ([_format length] == 0)
        return;
    
    format = MallocAtomic([_format cStringLength] + 1);
    [_format getCString:format];
    
    while (format[i] != '\0') {
        if (format[i] == self->decimalSeparator) {
            digitStatus = NO;
            decSepCount++;         
        }
        if (index("0123456789_", format[i]) != NULL)
            digitStatus = YES;                    
        
        i++;
    }
    lfFree(format); format = NULL;
    
    NSCAssert1(decSepCount <= 1,
               @"Too many decimal separators in format '%@' !",
               _format);
    NSCAssert1(digitStatus,
               @"format should be x or x.x (x is a digit or \'_\'): '%@' !",
               _format);
}

static unichar separatorFromString(NSString *_string)
{
   unichar theChar;

   if (_string == nil)        return 0;
   if ([_string length] == 0) return 0;
   
   if ([_string length] > 1)
       NSLog(@"WARNING: separator greater than 1 !");
   theChar = [_string characterAtIndex:0];

   NSCAssert(theChar < 256,
             @"unicode larger than 255, not supported (only 8-bit !)");
   NSCAssert(index("$0123456789#_", theChar) == NULL,
             @"invalid decimal separator char !");

   return theChar;
}

static NSString *cleanFormat(NSNumberFormatter *self, NSString *_format)
{
    const char *format = [_format cString];
    char *buffer = NULL;
    int  i,j;

    buffer = MallocAtomic([_format cStringLength] + 1);
    
    for (i = 0, j = 0; format[i] != '\0'; i++) {
        register char c = format[i];
        
        if ((c != self->thousandSeparator) && (c != '#')) {
            buffer[j] = format[i];
            j++;
        }
    }
    buffer[j] = '\0';
    format = NULL;
    
    return [NSString stringWithCStringNoCopy:buffer freeWhenDone:YES];
}


static NSString *_prefix(NSNumberFormatter *self, NSString *_format)
{
    const char *format = [_format cString];
    char *buffer = NULL;
    int  i = 0;

    buffer = MallocAtomic([_format cStringLength] + 1);

    while ((index("0123456789_", format[i]) == NULL) && (format[i] != '\0') &&
           (format[i] != self->decimalSeparator)) {
        buffer[i] = format[i];
        i++;
    }
    buffer[i] = '\0';
    format = NULL;
    
    return [NSString stringWithCStringNoCopy:buffer freeWhenDone:YES];
}

static NSString *_suffix(NSNumberFormatter *self, NSString *_format)
{
    char *buffer = NULL;
    char *format = NULL;
    int  i,j;

    format = MallocAtomic([_format cStringLength] +1);
    buffer = MallocAtomic([_format cStringLength] +1);
    [_format getCString:format];

    i = [_format cStringLength] - 1;
    j = 0;
    while ((index("0123456789_", format[i]) == NULL) && (i>=0) &&
           (format[i] !=self->decimalSeparator)) {
        buffer[j] = format[i];
        i--;
        j++;
    }
    buffer[j] = '\0';
    format[0] = '\0';

    i = strlen(buffer) - 1;
    j = 0;
    while (i >= 0) {
        format[j] = buffer[i];
        j++;
        i--;
    }
    format[j] = '\0';
    lfFree(buffer); buffer = NULL;
    
    return [NSString stringWithCStringNoCopy:format freeWhenDone:YES];
}

static NSString *digitsToDot(NSString *_string)
{
    const char *string = [_string cString];
    char *buffer = NULL;
    int  i = 0;
    int  j = 0;

    buffer = MallocAtomic([_string cStringLength] +1);

    while ((index("0123456789_", string[i]) == NULL) && (string[i] !='\0'))
        i++;

    while ((index("0123456789_", string[i]) != NULL) && (string[i] != '\0')) {
        buffer[j] = (string[i] == '_') ? ' ' : string[i];
        i++;
        j++;
    }
    buffer[j] = '\0';
    string = NULL;
    return [NSString stringWithCStringNoCopy:buffer freeWhenDone:YES];
}

static NSString *digitsFromDot(NSString *_string, NSString *_sep)
{
    char *buffer = NULL;
    char *string = NULL;
    char sep[2];
    int  i;
    int  j;

    if ([_string rangeOfString:_sep].length == 0)
        // if there is no decimal separator then return @""
        return @"";

    NSCAssert([_sep length] < 2, @"separator to long (max 1 char)");
    [_sep getCString:sep];
    
    i      = [_string cStringLength];
    buffer = MallocAtomic(i + 1);
    string = MallocAtomic(i + 1);
    [_string getCString:string]; string[i] = '\0';
    
    i = strlen(string) - 1;
    while ((index("0123456789_", string[i]) == NULL) && (i >= 0))
        i--;
    
    j = 0;
    while ((index(sep, string[i]) == NULL) && (i >= 0)) {
        if (index("0123456789_", string[i]))
            buffer[j] = (string[i] == '_') ? ' ' : string[i];
        i--;
        j++;
    }
    if ((index(sep, string[i]) == NULL) && (i == 0))
        buffer[0] = '\0';
    buffer[j] = '\0';

    string[0] = '\0';

    i = strlen(buffer) - 1;
    j = 0;
    while (i>=0) {
        string[j] = buffer[i];
        j++;
        i--;
    }
    string[j] = '\0';
    lfFree(buffer); buffer = NULL;

    return [NSString stringWithCStringNoCopy:string freeWhenDone:YES];
}

static BOOL digitsForString(NSNumberFormatter *self,
                            NSString **digitStr, NSString *_string)
{
    /* returns a string suitable for passing to atof() .. */
    const char *string;
    BOOL decStat = NO;
    BOOL status  = YES;
    char *buffer = NULL;
    int  i       = 0;
    int  j       = 0;
    int  k       = 0;
    
    string = [_string cString];
    buffer = MallocAtomic([_string cStringLength] +1);
    
    while ((index("0123456789", string[i]) == NULL) && (string[i] != '\0')) {
        if (string[i] == '-') {
            if (j == 0) {
                buffer[j] = string[i];
                j++;
            }
        }
        i++;
    }
    while (string[i] !='\0') {
        if (index("0123456789", string[i])) {
            buffer[j] = string[i];
            j++;
        }
        else if (string[i] == self->decimalSeparator) {
            if (!decStat) {
                decStat = YES;
                if (j == 0) {
                    buffer[j] = '0';
                    j++;
                }
                buffer[j] = '.'; //string[i];
                j++;
            }
            else break;
        }
        else if (string[i] == self->thousandSeparator) {
        }
        else
            break;
        i++;
    }
    for (k = strlen(string) - 1;
         (index("0123456789_", string[k]) == NULL) && (k >= 0);
         k--)
        ;

    for(; i < k; i++) {
        status    = NO;
        buffer[j] = string[i];
        j++;
    }
    buffer[j] = '\0';
    string = NULL;

    *digitStr = [NSString stringWithCStringNoCopy:buffer freeWhenDone:YES];
    buffer = NULL;

    return status; 
}

static BOOL checkMinMaxForNumber(NSNumberFormatter *self, NSNumber *_number)
{
    if ((self->minimum) && ([_number compare:self->minimum] < 0))
        return NO;

    if ((self->maximum) && ([_number compare:self->maximum] > 0))
        return NO;

    return YES;
}

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
