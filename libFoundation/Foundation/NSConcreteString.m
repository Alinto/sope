/* 
   NSConcreteString.m

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

#include <config.h>

#include <ctype.h>

#include <Foundation/common.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/StringExceptions.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSString.h>
#include <Foundation/NSConcreteString.h>

#include <extensions/objc-runtime.h>

#define COLLECT_STRING_CLUSTER_STATISTICS 0
#define PERF_8BIT_USE_OPT_COMPARE   1
#define PERF_SHTIN_USE_OWN_HASH     1
#define PERF_SHTIN_USE_OWN_EQUAL    1
#define PERF_SHTIN_USE_OWN_GETCHARS 1

static Class NS8BitStringClass          = Nil;
static Class NSMutable8BitStringClass   = Nil;
static Class NSShtInline8BitStringClass = Nil;
static Class NSInline8BitStringClass    = Nil;
static Class NSDataClass                = Nil;
static Class NSStringClass              = Nil;

#if COLLECT_STRING_CLUSTER_STATISTICS
static unsigned int NS8BitString_dealloc_count             = 0;
static unsigned int NSInline8BitString_dealloc_count       = 0;
static unsigned int NSInline8BitString_total_len           = 0;
static unsigned int NSShortInline8BitString_dealloc_count  = 0;
static unsigned int NSShortInline8BitString_total_len      = 0;
static unsigned int NSNonOwned8BitString_dealloc_count     = 0;
static unsigned int NSNonOwned8BitString_total_len         = 0;
static unsigned int NSOwned8BitString_dealloc_count        = 0;
static unsigned int NSOwned8BitString_total_len            = 0;
static unsigned int NSNonOwnedOpen8BitString_dealloc_count = 0;
static unsigned int NSNonOwnedOpen8BitString_total_len     = 0;
static unsigned int NSOwnedOpen8BitString_dealloc_count    = 0;
static unsigned int NSOwnedOpen8BitString_total_len        = 0;
static unsigned int NSRange8BitString_dealloc_count        = 0;
static unsigned int NSRange8BitString_total_len            = 0;

@implementation NSString(ClusterStatistics)

+ (void)printStatistics
{
    fprintf(stderr,
            "NSString class cluster statistics:\n"
            "  dealloc counts:\n"
            "    NS8BitString:                 %d\n"
            "      NSInline8BitString:         %d\n"
            "      NSShortInline8BitString:    %d\n"
            "      NSNonOwned8BitString:       %d\n"
            "        NSOwned8BitString:        %d\n"
            "          NSOwnedOpen8BitString:  %d\n"
            "        NSNonOwnedOpen8BitString: %d\n"
            "          NSRange8BitString:      %d\n"
            "  avg len (dealloc statistics):\n"
            "    NS8BitString:\n"
            "      NSInline8BitString:         %d\n"
            "      NSShortInline8BitString:    %d\n"
            "      NSNonOwned8BitString:       %d\n"
            "        NSOwned8BitString:        %d\n"
            "          NSOwnedOpen8BitString:  %d\n"
            "        NSNonOwnedOpen8BitString: %d\n"
            "          NSRange8BitString:      %d\n"
            ,
            NS8BitString_dealloc_count,
            NSInline8BitString_dealloc_count,
            NSShortInline8BitString_dealloc_count,
            NSNonOwned8BitString_dealloc_count,
            NSOwned8BitString_dealloc_count,
            NSOwnedOpen8BitString_dealloc_count,
            NSNonOwnedOpen8BitString_dealloc_count,
            NSRange8BitString_dealloc_count,
            NSInline8BitString_dealloc_count
              ? NSInline8BitString_total_len / NSInline8BitString_dealloc_count
              : 0,
            NSShortInline8BitString_dealloc_count
              ? NSShortInline8BitString_total_len /
                NSShortInline8BitString_dealloc_count
              : 0,
            NSNonOwned8BitString_dealloc_count
              ? NSNonOwned8BitString_total_len/NSNonOwned8BitString_dealloc_count
              : 0,
            NSOwned8BitString_dealloc_count
              ? NSOwned8BitString_total_len / NSOwned8BitString_dealloc_count
              : 0,
            NSOwnedOpen8BitString_dealloc_count
              ? NSOwnedOpen8BitString_total_len /
                NSOwnedOpen8BitString_dealloc_count
              : 0,
            NSNonOwnedOpen8BitString_dealloc_count
              ? NSNonOwnedOpen8BitString_total_len /
                NSNonOwnedOpen8BitString_dealloc_count
              : 0,
            NSRange8BitString_dealloc_count
              ? NSRange8BitString_total_len / NSRange8BitString_dealloc_count
              : 0
            );
}
- (void)printStatistics
{
    [NSString printStatistics];
}

@end
#endif /* COLLECT_STRING_CLUSTER_STATISTICS */

@implementation NS8BitString

+ (void)initialize 
{
    NS8BitStringClass          = [NS8BitString             class];
    NSMutable8BitStringClass   = [NSMutable8BitStringClass class];
    NSShtInline8BitStringClass = [NSShortInline8BitString  class];
    NSInline8BitStringClass    = [NSInline8BitStringClass  class];
    NSDataClass                = [NSData                   class];
    NSStringClass              = [NSString                 class];
}

#if COLLECT_STRING_CLUSTER_STATISTICS
- (void)dealloc
{
    NS8BitString_dealloc_count++;
    [super dealloc];
}
#endif

/* Accessing characters	*/

- (void)getCharacters:(unichar *)buffer
{
    register unsigned int i = 0, l;
    register unsigned char *bytes;
    
    if ((l = [self cStringLength]) == 0)
	return;
    
    bytes = (unsigned char *)[self __compact8BitBytes];
    for (i = 0; i < l; i++)
        buffer[i] = (unichar)bytes[i];
}
- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange
{
    register unsigned int i = 0;
    unsigned char *bytes;
    
    if (aRange.location + aRange.length > [self cStringLength]) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, [self cStringLength]]
            raise];
    }
    
    bytes = (unsigned char *)[self __compact8BitBytes];
    for (i = 0; i < aRange.length; i++)
        buffer[i] = bytes[i];
}

/* Dividing strings */

- (NSString *)substringWithRange:(NSRange)aRange
{
    [self subclassResponsibility:_cmd];
    return nil;
}

/* Finding characters and substrings */

- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet
  options:(unsigned int)mask range:(NSRange)aRange
{
    // ENCODINGS - this code applies to the system's default encoding
    unsigned int i = 0;

    IMP imp = [aSet methodForSelector:@selector(characterIsMember:)];
    unsigned char *bytes = (unsigned char *)[self __compact8BitBytes];

    if (NSMaxRange(aRange) > [self cStringLength]) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range %@ not in string 0x%08x of length %d",
	    	NSStringFromRange(aRange), self, [self cStringLength]] 
            raise];
    }

    if (mask & NSBackwardsSearch) {
	for (i = aRange.length - 1; i >= aRange.location; i--) {
	    unichar c = bytes[i];
	    
	    if ((*imp)(aSet, @selector(characterIsMember:), c) ||
		((mask & NSCaseInsensitiveSearch) && 
		 ((islower(c) &&
		  (*imp)(aSet, @selector(characterIsMember:), toupper(c))) ||
		 (isupper(c) &&
		  (*imp)(aSet, @selector(characterIsMember:), tolower(c))))
		 )) {
		    return NSMakeRange(i, 1);
		}
	}
    } 
    else {
        unsigned max = NSMaxRange(aRange);
	for (i = aRange.location; i < max; i++) {
	    unichar c = bytes[i];

	    if ((*imp)(aSet, @selector(characterIsMember:), c) ||
		((mask & NSCaseInsensitiveSearch) && 
		 ((islower(c) &&
		  (*imp)(aSet, @selector(characterIsMember:), toupper(c))) ||
		 (isupper(c) &&
		  (*imp)(aSet, @selector(characterIsMember:), tolower(c))))
		 )) {
          return NSMakeRange(i, 1);
		}
	}
    }
    
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)rangeOfString:(NSString*)aString
  options:(unsigned int)mask range:(NSRange)aRange
{
    // ENCODINGS - this code applies to the system's default encoding
    NSRange       range;
    unsigned char *mbytes;
    unsigned char *abytes;
    unsigned int  a;
    
    if (![aString isKindOfClass:NS8BitStringClass] &&
	![aString isKindOfClass:NSMutable8BitStringClass])
	    return [super rangeOfString:aString options:mask range:aRange];
    
    if ((aRange.location + aRange.length) > [self cStringLength]) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, [self cStringLength]] 
            raise];
    }

    mbytes = (unsigned char *)[self __compact8BitBytes] + aRange.location;
    abytes = (unsigned char *)[(id)aString __compact8BitBytes];
    a = [aString cStringLength];
    
    if ((a == 0) || (aRange.length < a))
        return NSMakeRange(0, 0);
    
    if (mask & NSAnchoredSearch)  {
	range.location = aRange.location + 
	    ((mask & NSBackwardsSearch) ? aRange.length - a : 0);
	range.length = a;
	
	if ([self compare:aString options:mask range:range] == NSOrderedSame)
	    return range;
	else
	    return NSMakeRange(0,0);
    }
    
    if (mask & NSBackwardsSearch) {	
	if (mask & NSCaseInsensitiveSearch) {
	    /* Backward case insensitive */
	    unsigned char cf;
            int n;

            cf = islower(abytes[0]) ? toupper(abytes[0]) : abytes[0];
            
	    for (n = aRange.length-a; n >= 0; n--) {
		unsigned char cm =
                    islower(mbytes[n]) ? toupper(mbytes[n]) : mbytes[n];
		unsigned char ca = cf;
                unsigned int i;
                
		if (cm != ca)
		    continue;
		for (i = 1; i < a; i++) {
		    cm = islower(mbytes[n+i]) ? 
			toupper(mbytes[n+i]) : mbytes[n+i];
		    ca = islower(abytes[i]) ? toupper(abytes[i]) : abytes[i];
		    if (cm != ca)
			break;
		}
		if (i == a) {
		    range.location = aRange.location + n;
		    range.length = a;
		    return range;
		}
	    }
	}
	else {
	    /* Backward case sensitive */
            int n;
	    for (n = (aRange.length - a); n >= 0; n--) {
                unsigned int i;
                
		if (mbytes[n] != abytes[0])
		    continue;
		for (i = 1; i < a; i++)
		    if (mbytes[n+i] != abytes[i])
			break;
		if (i == a) {
		    range.location = aRange.location + n;
		    range.length = a;
		    return range;
		}
	    }
	}
    }
    else {
	if (mask & NSCaseInsensitiveSearch) {
	    /* Forward case insensitive */
            int n;
	    unsigned char cf;

            cf = islower(abytes[0]) ? toupper(abytes[0]) : abytes[0];

	    for (n = 0; n + a <= aRange.length; n++) {
		unsigned char cm, ca;
                unsigned int i;
		
                cm = islower(mbytes[n]) ? toupper(mbytes[n]) : mbytes[n];
                ca = cf;
                
		if (cm != ca)
		    continue;
		for (i = 1; i < a; i++) {
		    cm = islower(mbytes[n+i]) ? 
			toupper(mbytes[n+i]) : mbytes[n+i];
		    ca = islower(abytes[i]) ? toupper(abytes[i]) : abytes[i];
		    if (cm != ca)
			break;
		}
		if (i == a) {
		    range.location = aRange.location + n;
		    range.length = a;
		    return range;
		}
	    }
	}
	else {
	    /* Forward case sensitive */
            int n;
            
	    for (n = 0; (n + a) <= aRange.length; n++) {
                unsigned int i;
                
		if (mbytes[n] != abytes[0])
		    continue;
		for (i = 1; i < a; i++)
		    if (mbytes[n+i] != abytes[i])
			break;
		if (i == a) {
		    range.location = aRange.location + n;
		    range.length   = a;
		    return range;
		}
	    }
	}
    }
    
    range.location = range.length = 0;
    return range;
}

- (NSComparisonResult)compare:(NSString *)aString
  options:(unsigned int)mask range:(NSRange)aRange
{
    // ENCODINGS - this code applies to the system's default encoding
    register unsigned char *mbytes;
    register unsigned char *abytes;
    unsigned int   i, n, a;
    
#if PERF_8BIT_USE_OPT_COMPARE /* optimized */
    register Class clazz;
    
    if (aString == nil) /* TODO: hh: AFAIK nil is not allowed in Cocoa? */
	return NSOrderedDescending;
    else if (aString == self)
	return NSOrderedSame;
    i = 0;
    for (clazz = *(id *)aString; clazz; clazz = class_get_super_class(clazz)) {
	if (clazz == NS8BitStringClass || clazz == NSMutable8BitStringClass) {
	    i = 1;
	    break;
	}
    }
    if (i == 0)
	return [super compare:aString options:mask range:aRange];
#else
    if (![aString isKindOfClass:NS8BitStringClass] &&
	![aString isKindOfClass:NSMutable8BitStringClass]) {
	return [super compare:aString options:mask range:aRange];
    }
#endif
    
    if (aRange.location + aRange.length > [self cStringLength]) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, [self cStringLength]]
            raise];
    }

    mbytes = (unsigned char *)[self __compact8BitBytes] + aRange.location;
    abytes = (unsigned char *)[(id)aString __compact8BitBytes];
    
    a = [aString cStringLength];
    n = MIN(a, aRange.length);
    
    if (mask & NSCaseInsensitiveSearch) {
	for (i = 0; i < n; i++) {
	    register unsigned char cm = 
		islower(mbytes[i]) ? toupper(mbytes[i]):mbytes[i];
	    register unsigned char ca = 
		islower(abytes[i]) ? toupper(abytes[i]):abytes[i];

	    if (cm < ca)
		return NSOrderedAscending;
	    if (cm > ca)
		return NSOrderedDescending;
	}
    }
    else {
	for (i = 0; i < n; i++) {
	    if (mbytes[i] < abytes[i])
		return NSOrderedAscending;
	    if (mbytes[i] > abytes[i])
		return NSOrderedDescending;
	}
    }
    
    if (aRange.length < a)
	return NSOrderedAscending;
    if (aRange.length > a)
	return NSOrderedDescending;

    return NSOrderedSame;
}

- (unsigned)hash
{
    static Class LastClass = Nil;
    static unsigned char *(*compact)(id, SEL) = NULL;
    static unsigned int  (*cstrlen)(id, SEL)  = NULL;
    register unsigned char *bytes;
    register unsigned      hash = 0, hash2;
    int i, n;
    
#if GNU_RUNTIME /* selector caching */
    if (LastClass != *(id *)self) {
	LastClass = *(id *)self;
	compact = (void *)method_get_imp(class_get_instance_method(LastClass, 
          @selector(__compact8BitBytes)));
	cstrlen = (void *)method_get_imp(class_get_instance_method(LastClass, 
          @selector(cStringLength)));
    }
    bytes = compact(self, NULL /* dangerous? */);
    n     = cstrlen(self, NULL /* dangerous? */);
#else
    bytes = [self __compact8BitBytes];
    n     = [self cStringLength];
#endif
    
    for (i = 0; i < n; i++) {
        hash <<= 4;
	// UNICODE - must use a for independent of composed characters
        hash += bytes[i];
        if ((hash2 = hash & 0xf0000000))
            hash ^= (hash2 >> 24) ^ hash2;
    }
    
    return hash;
}

/* Getting a shared prefix */

- (NSString *)commonPrefixWithString:(NSString*)aString
  options:(unsigned int)mask
{
    // ENCODINGS - this code applies to the system's default encoding
    NSRange range = {0, 0};
    unsigned char *mbytes;
    unsigned char *abytes;
    int           mLen, aLen, i;
    
    if (![aString isKindOfClass:NS8BitStringClass] &&
	![aString isKindOfClass:NSMutable8BitStringClass]) {
	    return [super commonPrefixWithString:aString options:mask];
    }
    
    mLen   = [self cStringLength];
    aLen   = [aString length];
    mbytes = (unsigned char *)[self __compact8BitBytes];
    abytes = (unsigned char *)[(NS8BitString *)aString __compact8BitBytes];

    for (i = 0; (i < mLen) && (i < aLen); i++) {
	unsigned char c1 = mbytes[i];
	unsigned char c2 = abytes[i];
        
        if (mask & NSCaseInsensitiveSearch) {
            c1 = tolower(c1);
            c2 = tolower(c2);
        }
        if (c1 != c2)
            break;
    }
    
    range.length = i;
    return [self substringWithRange:range];
}

/* Changing case */

- (NSString *)capitalizedString
{
    // ENCODINGS - this code applies to the system's default encoding
    int            i;
    BOOL           f      = YES;
    int            length = [self cStringLength];
    unsigned char* bytes  = (unsigned char *)[self __compact8BitBytes];
    unsigned char* chars  = MallocAtomic(sizeof(unichar)*(length+1));

    for (i = 0; i < length; i++) {
	unsigned char c = bytes[i];
	
	if (isspace(c))
	    f = YES;
	
	if (f) {
	    chars[i] = islower(c) ? toupper(c) : c;
	    f = NO;
	}
	else
	    chars[i] = isupper(c) ? tolower(c) : c;
    }
    chars[i] = 0;
    
    return AUTORELEASE([[NSOwned8BitString alloc]
                           initWithCString:(char *)chars length:length
			   copy:NO]);
}

- (NSString *)lowercaseString
{
    // ENCODINGS - this code applies to the system's default encoding
    int i;
    int length = [self cStringLength];
    unsigned char *bytes = (unsigned char *)[self __compact8BitBytes];
    unsigned char *chars = (unsigned char *)MallocAtomic(sizeof(unichar)*(length+1));

    for (i = 0; i < length; i++) {
	register unsigned char c = bytes[i];
	chars[i] = isupper(c) ? tolower(c) : c;
    }
    chars[i] = 0;

    return AUTORELEASE([[NSOwned8BitString alloc]
                           initWithCString:(char *)chars length:length copy:NO]);
}

- (NSString *)uppercaseString
{
    // ENCODINGS - this code applies to the system's default encoding
    int i;
    int length = [self cStringLength];
    unsigned char *bytes = (unsigned char *)[self __compact8BitBytes];
    unsigned char *chars = (unsigned char *)MallocAtomic(sizeof(unichar)*(length+1));

    for (i = 0; i < length; i++) {
	register unsigned char c = bytes[i];
	chars[i] = islower(c) ? toupper(c) : c;
    }
    
    chars[i] = 0;
    
    return AUTORELEASE([[NSOwned8BitString alloc]
                           initWithCString:(char *)chars length:length copy:NO]);
}

/* Working with C strings */

- (void)getCString:(char *)buffer maxLength:(unsigned int)maxLength
  range:(NSRange)aRange remainingRange:(NSRange*)leftoverRange
{
    unsigned char* bytes = (unsigned char *)[self __compact8BitBytes];
    unsigned int toMove = MIN(maxLength, aRange.length);
    unsigned int cLength = [self cStringLength];
    
    if (aRange.location + aRange.length > cLength) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, cLength] raise];
    }

    if (leftoverRange) {
	leftoverRange->location = aRange.location + toMove;
	leftoverRange->length = cLength - leftoverRange->location;
    }
    memcpy(buffer, bytes + aRange.location, toMove);
    if (toMove < maxLength)
	buffer[toMove] = '\0';
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag
{
    // UNICODE - remove this
    NSData *data;
    data = [self dataUsingEncoding:[NSString defaultCStringEncoding]];
    return writeToFile(path, data, flag);
}

- (Class)classForCoder
{
    return NS8BitStringClass;
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
    const unsigned char* bytes = (unsigned char *)[self __compact8BitBytes];
    int length = [self cStringLength];
    
    [aCoder encodeValueOfObjCType:@encode(int) at:&length];
    [aCoder encodeArrayOfObjCType:@encode(char) count:length at:bytes];
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    unsigned char *bytes;
    int length;

    RELEASE(self); self = nil;

    [aDecoder decodeValueOfObjCType:@encode(int) at:&length];
    bytes = MallocAtomic (length + 1);
    [aDecoder decodeArrayOfObjCType:@encode(char) count:length at:bytes];
    bytes[length] = '\0';
    return [[NSOwned8BitString alloc] 
	       initWithCString:(char *)bytes length:length copy:NO];
}

- (NSString *)stringRepresentation
{
    const unsigned char *cString;
    int i, length;

    cString = (unsigned char *)[self __compact8BitBytes];
    length  = [self cStringLength];
    
    if (cString == NULL)    return @"\"\"";
    if (length  == 0)       return @"\"\"";
    if (cString[0] == '\0') return @"\"\"";
    
    /* Check if the string can be parsed as a STRING token by the property list
       parser. Otherwise we must enclose it in double quotes. */
    if (lf_isPlistBreakChar(cString[0])) {
        return lf_quoteString((char *)cString, length);
    }

    for(i = 1; i < length; i++) {
        if (lf_isPlistBreakChar(cString[i]))
	    return lf_quoteString((char *)cString, length);
    }

    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    register Class clazz;
    int length;
    
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);

    length = [self cStringLength];
    
    clazz = length < 255
        ? NSShtInline8BitStringClass
        : NSInline8BitStringClass;
    
    return [[clazz allocForCapacity:length zone:zone]
                   initWithCString:[self __compact8BitBytes] length:length];
}

- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding
  allowLossyConversion:(BOOL)flag;
{
    /* NS8BitString */
    if (encoding == [NSStringClass defaultCStringEncoding]) {
        unsigned      len;
        unsigned char *buf = NULL;
        
        len  = [self cStringLength];
        buf = NSZoneMalloc(NULL, sizeof(unsigned char) * len + 1);
        [self getCString:(char *)buf];
        buf[len] = '\0';
        return [NSDataClass dataWithBytesNoCopy:(char *)buf
			    length:strlen((char *)buf)];
    }
    if (encoding == NSASCIIStringEncoding) {
        register unsigned len = [self cStringLength];
        register unsigned i;
        register unsigned char *buf;
            
        buf = NSZoneMalloc(NULL, sizeof(char) * len + 1);
        buf[len] = '\0';
            
        [self getCString:(char *)buf];            
        if (!flag) {
            /* check for strict ASCII */
            for (i = 0; i < len; i++)
                if (buf[i] > 127) return nil;
        }
        return [NSDataClass dataWithBytesNoCopy:buf length:len];
    }

    return [super dataUsingEncoding:encoding allowLossyConversion:flag];
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[NSMutableSimple8BitString allocWithZone:zone]
	initWithCString:[self __compact8BitBytes]
	length:[self cStringLength] copy:YES];
}

@end /* NS8BitString */

/*
 * Null terminated CString containing characters inline
 */
 
@implementation NSInline8BitString /* final */

+ (id)allocForCapacity:(unsigned int)capacity zone:(NSZone *)zone
{
    NSInline8BitString *str = (NSInline8BitString *)
	NSAllocateObject(self, capacity, zone);
    str->cLength = -1;
    return str;
}

- (id)init
{
    if (self->cLength != -1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    self->cLength = 0;
    self->cString[0] = 0;
    return self;
}

- (id)initWithCString:(const char*)byteString length:(unsigned int)length
{
    if (self->cLength != -1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    self->cLength = length;
    memcpy(self->cString, byteString, length);
    self->cString[length] = 0;
    return self;
}
- (id)initWithCharacters:(const unichar *)chars length:(unsigned int)length
{
    /* it must be ensured that char values are below 256 by the cluster ! */
    register unsigned i;
    if (self->cLength != -1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)]
            raise];
    }
    
    for (i = 0; i < length; i++)
        self->cString[i] = chars[i];
    self->cString[i] = '\0';
    self->cLength = i;
    return self;
}

#if COLLECT_STRING_CLUSTER_STATISTICS
- (void)dealloc
{
    NSInline8BitString_dealloc_count++;
    NSInline8BitString_total_len += self->cLength == -1 ? 0 : self->cLength;
    [super dealloc];
}
#endif

- (const char *)cString
{
    return (const char *)self->cString;
}

- (unsigned int)cStringLength
{
    return (self->cLength == -1) ? 0 : self->cLength;
}

- (unsigned int)length
{
    return (self->cLength == -1) ? 0 : self->cLength;
}

- (unichar)characterAtIndex:(unsigned int)index
{
    if (self->cLength == -1 || (int)index >= self->cLength) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"index %d out of range in string %x of length %d",
	    	index, self, self->cLength] raise];
    }
    // ENCODING
    return self->cString[index];
}

- (NSString *)substringWithRange:(NSRange)aRange
{
    if (aRange.location + aRange.length > (unsigned)self->cLength) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, cLength] raise];
    }
    if (aRange.length == 0)
	return @"";

    return AUTORELEASE([[NSRange8BitString alloc]
                           initWithString:self
                           bytes:((char *)self->cString + aRange.location)
                           length:aRange.length]);
}

- (char *)__compact8BitBytes
{
    return (char *)self->cString;
}

- (unsigned)hash
{
    register unsigned char *bytes;
    register unsigned      hash = 0, hash2;
    int i, n;
    
    bytes = self->cString;
    n     = (self->cLength == -1) ? 0 : self->cLength;
    
    for (i = 0; i < n; i++) {
        hash <<= 4;
	// UNICODE - must use a for independent of composed characters
        hash += bytes[i];
        if ((hash2 = hash & 0xf0000000))
            hash ^= (hash2 >> 24) ^ hash2;
    }
    
    return hash;
}

@end /* NSInline8BitString */

@implementation NSShortInline8BitString /* final */

+ (id)allocForCapacity:(unsigned int)capacity zone:(NSZone*)zone
{
    NSShortInline8BitString *str = (NSShortInline8BitString *)
	NSAllocateObject(self, capacity, zone);
    str->cLength = 255;
    return str;
}

- (id)init
{
    if (self->cLength != 255) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)]
            raise];
    }
    self->cLength = 0;
    self->cString[0] = 0;
    return self;
}

- (id)initWithCString:(const char*)byteString length:(unsigned int)length
{
    if (self->cLength != 255) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    self->cLength = length;
    memcpy(self->cString, byteString, length);
    self->cString[length] = 0;
    return self;
}
- (id)initWithCharacters:(const unichar *)chars length:(unsigned int)length
{
    /* it must be ensured that char values are below 256 by the cluster ! */
    register unsigned i;
    if (self->cLength != 255) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    
    for (i = 0; i < length; i++)
        self->cString[i] = chars[i];
    self->cString[i] = '\0';
    self->cLength = i;
    return self;
}

#if COLLECT_STRING_CLUSTER_STATISTICS
- (void)dealloc
{
    NSShortInline8BitString_dealloc_count++;
    NSShortInline8BitString_total_len +=
        self->cLength == 255 ? 0 : self->cLength;
    [super dealloc];
}
#endif

- (const char *)cString
{
    return (const char *)self->cString;
}

- (unsigned int)cStringLength
{
    return (self->cLength == 255) ? 0 : self->cLength;
}

- (unsigned int)length
{
    return (self->cLength == 255) ? 0 : self->cLength;
}

- (unichar)characterAtIndex:(unsigned int)index
{
    if ((self->cLength == 255) || (index >= self->cLength)) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"index %d out of range in string %x of length %d",
	    	index, self, self->cLength] raise];
    }
    // ENCODING
    return self->cString[index];
}

#if PERF_SHTIN_USE_OWN_GETCHARS
- (void)getCharacters:(unichar *)buffer
{
    register signed short i;
    
    i = self->cLength;
    if ((i == 255) || (i == 0)) /* empty string */
	return;
    
    for (i--; i >= 0; i--)
	buffer[i] = (unichar)(self->cString[i]);
}
- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange
{
    register unsigned int i = 0, l;
    
    i = aRange.location;
    l = i + aRange.length;
    if (l > ((self->cLength == 255) ? 0 : self->cLength)) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, [self length]] raise];
    }
    
    for (; i < l; i++)
	buffer[i] = (unichar)(self->cString[i]);
}
#endif

- (NSString *)substringWithRange:(NSRange)aRange
{
    if (aRange.location + aRange.length > self->cLength)
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, cLength] raise];

    if (aRange.length == 0)
	return @"";

    return AUTORELEASE([[NSRange8BitString alloc]
                           initWithString:self
                           bytes:((char *)self->cString + aRange.location)
                           length:aRange.length]);
}

- (char *)__compact8BitBytes
{
    return (char *)self->cString;
}

- (NSComparisonResult)compare:(NSString *)aString
  options:(unsigned int)mask range:(NSRange)aRange
{
    // ENCODINGS - this code applies to the system's default encoding
    register unsigned char *mbytes, *abytes;
    register Class clazz;
    unsigned int   i, n, a;
    
#if 1 /* optimized */
    if (aString == nil) /* TODO: hh: AFAIK nil is not allowed in Cocoa? */
	return NSOrderedDescending;
    else if (aString == self)
	return NSOrderedSame;
    i = 0;
    for (clazz = *(id *)aString; clazz; clazz = class_get_super_class(clazz)) {
	if (clazz == NS8BitStringClass || clazz == NSMutable8BitStringClass) {
	    i = 1;
	    break;
	}
    }
    if (i == 0)
	return [super compare:aString options:mask range:aRange];
#else
    if (![aString isKindOfClass:NS8BitStringClass] &&
	![aString isKindOfClass:NSMutable8BitStringClass]) {
	return [super compare:aString options:mask range:aRange];
    }
#endif
    
    if ((aRange.location + aRange.length) > 
	((self->cLength == 255) ? 0 : self->cLength)) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, [self cStringLength]]
            raise];
    }

    mbytes = self->cString + aRange.location;
    abytes = (unsigned char *)[(id)aString __compact8BitBytes];
    
    a = [aString cStringLength];
    n = MIN(a, aRange.length);
    
    if (mask & NSCaseInsensitiveSearch) {
	for (i = 0; i < n; i++) {
	    register unsigned char cm = 
		islower(mbytes[i]) ? toupper(mbytes[i]):mbytes[i];
	    register unsigned char ca = 
		islower(abytes[i]) ? toupper(abytes[i]):abytes[i];

	    if (cm < ca)
		return NSOrderedAscending;
	    if (cm > ca)
		return NSOrderedDescending;
	}
    }
    else {
	for (i = 0; i < n; i++) {
	    if (mbytes[i] < abytes[i])
		return NSOrderedAscending;
	    if (mbytes[i] > abytes[i])
		return NSOrderedDescending;
	}
    }
    
    if (aRange.length < a)
	return NSOrderedAscending;
    if (aRange.length > a)
	return NSOrderedDescending;

    return NSOrderedSame;
}

#if PERF_SHTIN_USE_OWN_HASH
- (unsigned)hash
{
    /* 
       according to Valgrind this takes 3.13% of the runtime, can this be 
       further optimized without breaking dictionary performance due to
       broken hash values?
    */
    register unsigned char *bytes;
    register unsigned      hash = 0, hash2;
    register int i, n;
    
    bytes = self->cString;
    n     = (self->cLength == 255) ? 0 : self->cLength;
    
    for (i = 0; i < n; i++) {
        hash <<= 4;
	// UNICODE - must use a for independent of composed characters
        hash += bytes[i];
        if ((hash2 = hash & 0xf0000000))
            hash ^= (hash2 >> 24) ^ hash2;
    }
    
    return hash;
}
#endif

#if PERF_SHTIN_USE_OWN_EQUAL
- (BOOL)isEqual:(id)aString
{
    register unsigned char *mbytes, *abytes;
    register Class clazz;
    unsigned int   i, n, a;
    NSRange range;
    
    if (self == aString)
	return YES;
    else if (aString == nil)
	return NO;
    
    i = 0; n = 0;
    if (*(id *)aString == *(id *)self) { /* exactly the same class */
	i = 1; /* is NSString subclass             */
	n = 1; /* is 8-bit string subclass         */
	a = 1; /* is exactly the same string class */
    }
    else {
	a = 0;
	for (clazz=*(id *)aString; clazz; clazz=class_get_super_class(clazz)) {
	    if (clazz==NS8BitStringClass || clazz==NSMutable8BitStringClass) {
		i = 1; // is NSString subclass
		n = 1; // is 8-bit string subclass
		break;
	    }
	    if (clazz == NSStringClass) {
		i = 1; // is NSString subclass 
		n = 0; // is not an 8-bit string subclass
		break;
	    }
	}
	if (i == 0) // not a NSString subclass
	    return NO;
    }
    range.length = (self->cLength == 255) ? 0 : self->cLength;
    if (n == 0) { // is not an 8-bit string subclass, use compare
	range.location = 0;
	return [self compare:aString options:0 range:range] == NSOrderedSame;
    }
    
    /* other string is 8 bit */
    
    if (a == 1) { /* exact string class, do not call method */
	a = (((NSShortInline8BitString *)aString)->cLength == 255) 
	    ? 0 
	    : ((NSShortInline8BitString *)aString)->cLength;
	if (a != range.length)
	    /* strings differ in length */
	    return NO;
    }
    else if ((a = [aString cStringLength]) != range.length)
	/* strings differ in length */
	return NO;
    
    /* same length */
    
    mbytes = self->cString;
    abytes = (unsigned char *)[(id)aString __compact8BitBytes];
    
    /* using memcmp is probably faster than looping on our own */
    return memcmp(self->cString, abytes, a) == 0 ? YES : NO;
}
#endif

@end /* NSShortInline8BitString */

@implementation NSCharacter8BitString /* final */

- (id)init
{
    self->c[0] = '\0';
    self->c[1] = '\0';
    return self;
}

- (id)initWithCString:(const char*)byteString length:(unsigned int)_length
{
    if (_length != 1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"%@ can only handle a singe char", [self class]] raise];
    }
    self->c[0] = byteString[0];
    self->c[1] = '\0';
    
    return self;
}
- (id)initWithCharacters:(const unichar *)chars length:(unsigned int)_length
{
    if (_length != 1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"%@ can only handle a singe char", [self class]] raise];
    }
    self->c[0] = (char)chars[0];
    self->c[1] = '\0';
    
    return self;
}

- (const char *)cString
{
    return (const char *)&(self->c[0]);
}

- (unsigned int)cStringLength
{
  return 1;
}

- (unsigned int)length
{
  return 1;
}

- (unichar)characterAtIndex:(unsigned int)index
{
    if (index != 0) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"index %d out of range in string %x of length 1",
	    	index, self] raise];
    }
    // ENCODING
    return self->c[0];
}

- (NSString *)substringWithRange:(NSRange)aRange
{
  if (aRange.location == 0 && aRange.length == 1)
    return self;
  if (aRange.length == 0)
    return @"";

  [[[IndexOutOfRangeException alloc] 
	  initWithFormat:@"range (%d,%d) in string %x of length 1",
	  aRange.location, aRange.length, self] raise];
  return nil;
}

- (char *)__compact8BitBytes
{
    return (char *)&(self->c[0]);
}

- (unsigned)hash
{
    register unsigned hash = 0, hash2;
    
    hash <<= 4;
    // UNICODE - must use a for independent of composed characters
    hash += self->c[0];
    if ((hash2 = hash & 0xf0000000))
	hash ^= (hash2 >> 24) ^ hash2;
    
    return hash;
}

@end /* NSCharacter8BitString */


/*
 * String containing non-owned, zero termintated c-string
 */

@implementation NSNonOwned8BitString

- (id)init
{
    if (self->cLength || self->cString) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)]
            raise];
    }
    self->cLength = 0;
    self->cString = (unsigned char *)"";
    return self;
}

- (id)initWithCString:(char *)byteString
  length:(unsigned int)length copy:(BOOL)flag
{
    if (self->cLength || self->cString) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)]
            raise];
    }
    if (flag) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s with flag set to YES to %@ to instance", 
	    sel_get_name(_cmd), NSStringFromClass([self class])] raise];
    }
    cLength = length;
    cString = (unsigned char *)byteString;
    return self;
}

#if COLLECT_STRING_CLUSTER_STATISTICS
- (void)dealloc
{
    NSNonOwned8BitString_dealloc_count++;
    NSNonOwned8BitString_total_len += self->cLength;
    [super dealloc];
}
#endif

- (const char *)cString
{
    return (const char *)self->cString;
}

- (unsigned int)cStringLength
{
    return self->cLength;
}

- (unsigned int)length
{
    return self->cLength;
}

- (unichar)characterAtIndex:(unsigned int)index
{
    if ((int)self->cLength == -1 || (index >= (unsigned)self->cLength)) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"index %d out of range in string %x of length %d",
	    	index, self, cLength] raise];
    }
    // ENCODING
    return self->cString[index];
}

- (NSString *)substringWithRange:(NSRange)aRange
{
    if (aRange.location + aRange.length > cLength) {
	[[[IndexOutOfRangeException alloc] 
                  initWithFormat:@"range (%d,%d) in string %x of length %d",
                  aRange.location, aRange.length, self, cLength] raise];
    }
    
    if (aRange.length == 0)
	return @"";

    return AUTORELEASE([[NSRange8BitString alloc]
                           initWithString:self
                           bytes:(char *)cString + aRange.location
                           length:aRange.length]);
}

- (char *)__compact8BitBytes
{
    return (char *)self->cString;
}

@end /* NSNonOwned8BitString */

@implementation NSOwned8BitString

- (id)init
{
    if (self->cLength || self->cString) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }

    self->cLength = 0;
    self->cString = NSZoneMallocAtomic([self zone], sizeof(char));
    self->cString[0] = 0;
    return self;
}

- (id)initWithCString:(char*)byteString
  length:(unsigned int)length
  copy:(BOOL)flag
{
    if (self->cLength != 0 || self->cString != NULL) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)]
            raise];
    }

    self->cLength = length;
    if (flag) {
	self->cString = NSZoneMallocAtomic([self zone], sizeof(char)*(length+1));
	memcpy(self->cString, byteString, length);
	self->cString[self->cLength] = 0;
    }
    else
	self->cString = (unsigned char *)byteString;
    return self;
}

- (void)dealloc
{
#if COLLECT_STRING_CLUSTER_STATISTICS
    NSOwned8BitString_dealloc_count++;
    NSOwned8BitString_total_len += self->cLength;
#endif
    lfFree(self->cString);
    [super dealloc];
}

@end /* NSOwned8BitString */


#define USE_LIB_FOUNDATION_CUSTOM_CONSTSTR 1
#define USE_LIB_FOUNDATION_CONSTSTR 1

#if USE_LIB_FOUNDATION_CONSTSTR

#if USE_LIB_FOUNDATION_CUSTOM_CONSTSTR
#  define NXConstantString NSConstantString
#endif

/* this requires that we use the special libFoundation libobjc */
@implementation NXConstantString

- (oneway void)release
{
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return 1;
}

- (id)autorelease
{
    return self;
}

- (void)dealloc
{
    [self shouldNotImplement:_cmd];

    /* this is to please gcc 4.1 which otherwise issues a warning (and we
       don't know the -W option to disable it, let me know if you do ;-)*/
    if (0) [super dealloc];
}

@end /* NXConstantString */

#if USE_LIB_FOUNDATION_CUSTOM_CONSTSTR
#  undef NXConstantString
#endif

#else

#warning NOT USING BUILTIN NXConstantString

@interface DummyNXConstantString : NSNonOwned8BitString
@end

@implementation DummyNXConstantString
- (oneway void)release
{
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return 1;
}

- (id)autorelease
{
    return self;
}

- (void)dealloc
{
    [self shouldNotImplement:_cmd];
}

+ (void)load
{
    static BOOL didLoad = NO;

#warning DEBUG LOG
    printf("LOAD DUMMY\n");

    if (!didLoad) {
        Class metaClass;
        Class constantStringClass;
        Class constantStringMetaClass;

        didLoad = YES;
	
        metaClass               = ((DummyNXConstantString*)self)->isa;
        constantStringClass     = objc_lookup_class ("NXConstantString");
        constantStringMetaClass = constantStringClass->class_pointer;
        
        memcpy(constantStringClass,     self,      sizeof (struct objc_class));
        memcpy(constantStringMetaClass, metaClass, sizeof (struct objc_class));
        
        constantStringClass->name
            = constantStringMetaClass->name
            = "NXConstantString";
	
	/* 
	   Note: this doesn't work for dynamically loaded NSString categories,
	         that is categories either contained in bundles OR in libraries
		 which are loaded on-demand in case a bundle is loaded.
	*/
        class_add_behavior(constantStringClass, self);
    }
}

@end /* DummyNXConstantString */
#endif

@implementation NSNonOwnedOpen8BitString

#if COLLECT_STRING_CLUSTER_STATISTICS
- (void)dealloc
{
    NSNonOwnedOpen8BitString_dealloc_count++;
    NSNonOwnedOpen8BitString_total_len += self->cLength;
    [super dealloc];
}
#endif

- (const char *)cString
{
    unsigned char *str;
    
    str = NSZoneMallocAtomic([self zone], sizeof(char)*(self->cLength + 1));
    memcpy(str, self->cString, self->cLength);
    str[cLength] = 0;
#if !LIB_FOUNDATION_BOEHM_GC
    [NSAutoreleasedPointer autoreleasePointer:str];
#endif
    return (const char *)str;
}

@end /* NSNonOwnedOpen8BitString */

@implementation NSOwnedOpen8BitString /* final */

#if COLLECT_STRING_CLUSTER_STATISTICS
- (void)dealloc
{
    NSOwnedOpen8BitString_dealloc_count++;
    NSOwnedOpen8BitString_total_len += self->cLength;
    [super dealloc];
}
#endif

- (id)initWithCString:(char *)byteString
  length:(unsigned int)length copy:(BOOL)flag
{
    if (self->cLength || self->cString) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    if (length != 0 && byteString == NULL) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"passed NULL cstring to %s with a non-null length (%i)!", 
            sel_get_name(_cmd), length]
            raise];
    }
    
    if (strlen(byteString) < length) {
        printf("LENGTH DIFFERS: %ld vs %d\n", 
	       (unsigned long)strlen(byteString), length);
        abort();
    }
    
    self->cLength = length;
    if (flag) {
        /* TODO: this is not tracked in dealloc? */
	self->cString = 
            NSZoneMallocAtomic([self zone], sizeof(char)*(length + 1));
	memcpy(cString, byteString, length);
        cString[length] = 0;
    }
    else
	self->cString = (unsigned char *)byteString;
    return self;
}

- (const char *)cString
{
    unsigned char *str = MallocAtomic(sizeof(char)*(self->cLength + 1));
    
    memcpy(str, self->cString, self->cLength);
    str[self->cLength] = 0;
#if !LIB_FOUNDATION_BOEHM_GC
    [NSAutoreleasedPointer autoreleasePointer:str];
#endif
    return (const char *)str;
}

@end /* NSOwnedOpen8BitString */


@implementation NSRange8BitString /* final */

- (id)initWithString:(NSString *)aParent 
  bytes:(char *)bytes length:(unsigned int)length
{
    if (self->cLength != 0 || self->cString != NULL) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)]
            raise];
    }
    
    self->cString = (unsigned char *)bytes;
    self->cLength = length;
    self->parent  = RETAIN(aParent);
    return self;
}

- (void)dealloc
{
#if COLLECT_STRING_CLUSTER_STATISTICS
    NSRange8BitString_dealloc_count++;
    NSRange8BitString_total_len += self->cLength;
#endif
    RELEASE(self->parent);
    [super dealloc];
}

- (NSString *)substringWithRange:(NSRange)aRange
{
    if (aRange.location + aRange.length > cLength) {
	[[[IndexOutOfRangeException alloc] 
                  initWithFormat:@"range (%d,%d) in string %x of length %d",
                  aRange.location, aRange.length, self, cLength] raise];
    }
    
    if (aRange.length == 0)
	return @"";

    return AUTORELEASE([[NSRange8BitString alloc] 
                           initWithString:parent
                           bytes:((char *)cString + aRange.location)
                           length:aRange.length]);
}

- (unsigned)hash
{
    register unsigned char *bytes;
    register unsigned      hash = 0, hash2;
    int i, n;
    
    bytes = self->cString;
    n     = self->cLength;
    
    for (i = 0; i < n; i++) {
        hash <<= 4;
	// UNICODE - must use a for independent of composed characters
        hash += bytes[i];
        if ((hash2 = hash & 0xf0000000))
            hash ^= (hash2 >> 24) ^ hash2;
    }
    
    return hash;
}

@end /* NSRange8BitString */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
