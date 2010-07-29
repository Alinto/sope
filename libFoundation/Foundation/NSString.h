/* 
   NSString.h

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

#ifndef __NSString_h__
#define __NSString_h__

#include <limits.h>
#include <stdarg.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSDictionary;
@class NSMutableDictionary;
@class NSArray;
@class NSData;
@class NSCharacterSet;
@class NSURL;

/* String limits */
#define NSMaximumStringLength   (INT_MAX-1)
#define NSHashStringLength      63

/* Known encodings */
typedef unsigned NSStringEncoding;

enum { 
    NSASCIIStringEncoding                 = 1,
    NSNEXTSTEPStringEncoding              = 2,
    NSJapaneseEUCStringEncoding           = 3,
    NSUTF8StringEncoding                  = 4,
    NSISOLatin1StringEncoding             = 5,
    NSSymbolStringEncoding                = 6,
    NSNonLossyASCIIStringEncoding         = 7,
    NSShiftJISStringEncoding              = 8,
    NSISOLatin2StringEncoding             = 9,
    NSUnicodeStringEncoding               = 10,
    NSWindowsCP1251StringEncoding         = 11,
    NSWindowsCP1252StringEncoding         = 12,
    NSWindowsCP1253StringEncoding         = 13,
    NSWindowsCP1254StringEncoding         = 14,
    NSWindowsCP1250StringEncoding         = 15,
    NSISO2022JPStringEncoding             = 21,
    
    /* not in MacOSX: */
    NSAdobeStandardCyrillicStringEncoding,
    NSWinLatin1StringEncoding,
    NSISOLatin9StringEncoding
};

/* 
 * Flags passed to compare & rangeOf...: With a zero mask passed in, 
 * the searches are case sensitive, from the beginning, are non-anchored, 
 * and take Unicode floating diacritics and other non-visible characters into
 * account.
 */

enum {
    NSCaseInsensitiveSearch = 1,
    NSLiteralSearch         = 2, /* Character-by-character search */
    NSBackwardsSearch       = 4, /* Search backwards in the range */
    NSAnchoredSearch        = 8  /* Search anchored within specified range */
};

/* Unicode character is 16bit wide (assumes short is 16bit wide in gcc) */
typedef unsigned short unichar;

/*
 * NSString
 *
 * primitive methods:
 *      - characterAtIndex:
 *      - length:
 *      - init* as appropriate
 */

@interface NSString : NSObject <NSCoding, NSCopying, NSMutableCopying>
/* Getting a string's length */
- (unsigned int)length;

/* Accessing characters */
- (unichar)characterAtIndex:(unsigned int)index;
- (void)getCharacters:(unichar*)buffer;
- (void)getCharacters:(unichar*)buffer range:(NSRange)aRange;

/* Combining strings */ 
- (NSString*)stringByAppendingString:(NSString*)aString;
- (NSString*)stringByAppendingFormat:(NSString*)format,...;
- (NSString*)stringByAppendingFormat:(NSString*)format 
  arguments:(va_list)argList;
- (NSString*)stringByPrependingString:(NSString*)aString;
- (NSString*)stringByPrependingFormat:(NSString*)format,...;
- (NSString*)stringByPrependingFormat:(NSString*)format 
  arguments:(va_list)argList;

/* Dividing strings */
- (NSArray*)componentsSeparatedByString:(NSString*)separator;
- (NSString*)substringFromIndex:(unsigned int)index;
- (NSString*)substringWithRange:(NSRange)aRange;
- (NSString*)substringFromRange:(NSRange)aRange;
        // obsolete; use instead -substringWithRange:
- (NSString*)substringToIndex:(unsigned int)index;

- (NSString *)stringByTrimmingCharactersInSet:(NSCharacterSet *)set;

/* Finding characters and substrings */
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet
  options:(unsigned int)mask;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet
  options:(unsigned int)mask range:(NSRange)aRange;
- (NSRange)rangeOfString:(NSString*)string;
- (NSRange)rangeOfString:(NSString*)string options:(unsigned int)mask;
- (NSRange)rangeOfString:(NSString*)aString
  options:(unsigned int)mask range:(NSRange)aRange;
- (unsigned int)indexOfString:(NSString*)substring;
- (unsigned int)indexOfString:(NSString*)substring fromIndex:(unsigned)index;
- (unsigned int)indexOfString:(NSString*)substring range:(NSRange)aRange;

/* Determining composed character sequences */
- (NSRange)rangeOfComposedCharacterSequenceAtIndex:(unsigned int)anIndex;

/* Converting string contents into a property list */
- (id)propertyList;
- (NSMutableDictionary*)propertyListFromStringsFileFormat;

/* Identifying and comparing strings */
- (NSComparisonResult)caseInsensitiveCompare:(NSString*)aString;
- (NSComparisonResult)compare:(id)aString;
- (NSComparisonResult)compare:(NSString*)aString options:(unsigned int)mask;
- (NSComparisonResult)compare:(NSString*)aString
  options:(unsigned int)mask range:(NSRange)aRange;
- (BOOL)hasPrefix:(NSString*)aString;
- (BOOL)hasSuffix:(NSString*)aString;

- (BOOL)isEqual:(id)anObject;
- (BOOL)isEqualToString:(NSString*)aString;
- (unsigned)hash;       

/* Getting a shared prefix */
- (NSString*)commonPrefixWithString:(NSString*)aString
  options:(unsigned int)mask;

/* Changing case */
- (NSString*)capitalizedString;
- (NSString*)lowercaseString;
- (NSString*)uppercaseString;

/* Getting C strings */
- (const char *)cString;
- (unsigned int)cStringLength;
- (void)getCString:(char *)buffer;
- (void)getCString:(char *)buffer maxLength:(unsigned int)maxLength;
- (void)getCString:(char *)buffer maxLength:(unsigned int)maxLength
  range:(NSRange)aRange remainingRange:(NSRange *)leftoverRange;
- (const char *)UTF8String;

/* Getting numeric values */
- (double)doubleValue;
- (float)floatValue;
- (int)intValue;

/* Working with encodings */
+ (NSStringEncoding *)availableStringEncodings;
+ (NSStringEncoding)defaultCStringEncoding;
+ (NSString *)localizedNameOfStringEncoding:(NSStringEncoding)encoding;
- (BOOL)canBeConvertedToEncoding:(NSStringEncoding)encoding;
- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding;
- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding
  allowLossyConversion:(BOOL)flag;
- (NSStringEncoding)fastestEncoding;
- (NSStringEncoding)smallestEncoding;
- (BOOL)getBytes:(void *)bytes maxLength:(unsigned int)maxLength
  inEncoding:(NSStringEncoding)encoding
  allowLossesInConversion:(BOOL)allowLossesInConversion
  fromRange:(NSRange)fromRange
  usedRange:(NSRange *)usedRange
  remainingRange:(NSRange *)remainingRange;

/* Writing to a file */
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag;
@end

@interface NSString(NSStringCreation)
+ (id)localizedStringWithFormat:(NSString*)format,...;
+ (id)stringWithCharacters:(const unichar*)chars
  length:(unsigned int)length;
+ (id)stringWithCharactersNoCopy:(unichar *)chars        
  length:(unsigned int)length freeWhenDone:(BOOL)flag;
+ (id)stringWithString:(NSString *)aString;
+ (id)stringWithCString:(const char *)byteString;
+ (id)stringWithUTF8String:(const char *)byteString;
+ (NSString *)stringWithCString:(const char*)byteString
  length:(unsigned int)length;
+ (id)stringWithCStringNoCopy:(char *)byteString
  freeWhenDone:(BOOL)flag;
+ (NSString *)stringWithCStringNoCopy:(char *)byteString
  length:(unsigned int)length freeWhenDone:(BOOL)flag;
+ (id)stringWithFormat:(NSString *)format,...;
+ (id)stringWithFormat:(NSString *)format arguments:(va_list)argList;
+ (id)stringWithContentsOfFile:(NSString *)path;
+ (id)stringWithContentsOfURL:(NSURL *)_url;
+ (id)string;
@end

@interface NSString(NSStringInitialization)
- (id)init;
- (id)initWithCharacters:(const unichar*)chars length:(unsigned int)length;
- (id)initWithCharactersNoCopy:(unichar*)chars length:(unsigned int)length 
  freeWhenDone:(BOOL)flag;
- (id)initWithCString:(const char*)byteString;
- (id)initWithUTF8String:(const char*)byteString;
- (id)initWithBytes:(const void *)_bytes length:(unsigned)_length 
  encoding:(NSStringEncoding)_enc;
- (id)initWithBytesNoCopy:(void *)_bytes length:(unsigned)_length 
  encoding:(NSStringEncoding)_enc freeWhenDone:(BOOL)_fwd;
- (id)initWithCString:(const char*)byteString length:(unsigned int)length;
- (id)initWithCStringNoCopy:(char*)byteString freeWhenDone:(BOOL)flag;
- (id)initWithCStringNoCopy:(char*)byteString length:(unsigned int)length 
  freeWhenDone:(BOOL)flag;
- (id)initWithString:(NSString*)aString;
- (id)initWithFormat:(NSString*)format, ...;
- (id)initWithFormat:(NSString*)format arguments:(va_list)argList;
- (id)initWithFormat:(NSString*)format
  locale:(NSDictionary*)dictionary, ...;
- (id)initWithFormat:(NSString*)format 
  locale:(NSDictionary*)dictionary arguments:(va_list)argList;  
- (id)initWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
- (id)initWithContentsOfFile:(NSString *)path;
- (id)initWithContentsOfURL:(NSURL *)_url;
@end


/*
 * NSMutableString
 *
 * primitive methods:
 *      - characterAtIndex:
 *      - length:
 *      - replaceCharactersInRange:withString:
 *      - init* as appropriate
 */

@interface NSMutableString : NSString
/* Modifying a string */
- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString*)aString;
- (void)appendFormat:(NSString*)format,...;
- (void)appendFormat:(NSString*)format arguments:(va_list)argList;
- (void)appendString:(NSString*)aString;
- (void)prependFormat:(NSString*)format,...;
- (void)prependFormat:(NSString*)format arguments:(va_list)argList;
- (void)prependString:(NSString*)aString;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)insertString:(NSString*)aString atIndex:(unsigned)index;
- (void)setString:(NSString*)aString;
@end

@interface NSMutableString(NSStringCreation)
+ (id)stringWithCapacity:(unsigned int)capacity;
+ (id)string;
@end

@interface NSMutableString(NSStringInitialization)
- (id)initWithCapacity:(unsigned int)capacity;
@end

/*
 * Additions made in GNUstep base
 *
 * Added to lF to support compilation of GNUstep stuff, do avoid to
 * use such functions - they make you loose OpenStep compatibility !
 *
 * NOTE: apparently this was removed from gstep-base in the meantime, sigh
 */

@interface NSString(GSAdditions)

- (NSString *)stringWithoutPrefix:(NSString *)_prefix;
- (NSString *)stringWithoutSuffix:(NSString *)_suffix;

- (NSString *)stringByReplacingString:(NSString *)_orignal
  withString:(NSString *)_replacement;

- (NSString *)stringByTrimmingLeadWhiteSpaces;
- (NSString *)stringByTrimmingTailWhiteSpaces;
- (NSString *)stringByTrimmingWhiteSpaces;

- (NSString *)stringByTrimmingLeadSpaces;
- (NSString *)stringByTrimmingTailSpaces;
- (NSString *)stringByTrimmingSpaces;

@end

@interface NSMutableString(GNUstepCompatibility)

- (void)trimLeadSpaces;
- (void)trimTailSpaces;
- (void)trimSpaces;

@end

/* Errors & exceptions for strings */

LF_EXPORT NSString* NSStringBoundsError;

/*
 * Include header for concrete subclasses for debug info
 */

#include <Foundation/NSConcreteString.h>

#endif /* __NSString_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
