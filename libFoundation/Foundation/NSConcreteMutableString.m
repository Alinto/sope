/* 
   NSMutableSimple8BitString.m

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

#include <Foundation/NSConcreteString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/exceptions/StringExceptions.h>
#include <Foundation/common.h>
#include <extensions/objc-runtime.h>

@implementation NSMutable8BitString

+ (void)initialize
{
    static BOOL initialized = NO;

    if(!initialized) {
	initialized = YES;
	class_add_behavior(self, [NS8BitString class]);
    }
}

- (id)initWithString:(NSString*)aString
{
    if (![aString isKindOfClass:[NS8BitString class]] &&
	![aString isKindOfClass:[NSMutable8BitString class]])
	    return [super initWithString:(NSString*)aString];
    
    return [self initWithCString:[(id)aString __compact8BitBytes]
	length:[aString cStringLength] copy:YES];
}

- (id)initWithContentsOfFile:(NSString *)_path
{
    unsigned char *bytes = NULL;
    unsigned len;

    if ((bytes = NSReadContentsOfFile(_path, 1, &len))) {
        bytes[len] = '\0';
        return [self initWithCString:(char *)bytes length:len copy:NO];
    }    
    else {
        self = AUTORELEASE(self);
        return nil;
    }
}

- (id)copyWithZone:(NSZone*)zone
{
    Class clazz;
    int length = [self cStringLength];

    clazz = (length < 255)
        ? [NSShortInline8BitString class]
        : [NSInline8BitString class];
    
    return [[clazz allocForCapacity:length zone:zone]
                   initWithCString:[self __compact8BitBytes] length:length];
}

- (Class)classForCoder
{
    return [NSMutable8BitString class];
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    unsigned char *bytes;
    int length;

    RELEASE(self); self = nil;
    
    [aDecoder decodeValueOfObjCType:@encode(int) at:&length];
    bytes = MallocAtomic (length);
    [aDecoder decodeArrayOfObjCType:@encode(char) count:length at:bytes];
    return [[NSMutableSimple8BitString alloc]
               initWithCString:(char *)bytes length:length copy:NO];
}

- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding
  allowLossyConversion:(BOOL)flag;
{
    /* NSMutableSimple8BitString */
    
    if (encoding == [NSString defaultCStringEncoding]) {
        unsigned      len;
        unsigned char *buf;
        
        len = [self cStringLength];
        buf = NSZoneMallocAtomic(NULL, len + 1);
        [self getCString:(char *)buf]; buf[len] = '\0';
        
        return [NSData dataWithBytesNoCopy:buf length:len];
    }
    else if (encoding == NSASCIIStringEncoding) {
        unsigned      len;
        unsigned char *buf;
        unsigned      i;
        
        len = [self cStringLength];
        buf = NSZoneMallocAtomic(NULL, len + 1);
        [self getCString:(char *)buf]; buf[len] = '\0';
        
        if (!flag) {
            /* check for strict ANSI */
            for (i = 0; i < len; i++)
                if (buf[i] > 127) return nil;
        }
        return [NSData dataWithBytesNoCopy:buf length:len];
    }
    else
        return [super dataUsingEncoding:encoding allowLossyConversion:flag];
}

/* NS8BitString class (formerly added using add_behaviour) */

/* Accessing characters	*/

- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange
{
    register unsigned int i = 0;
    register unsigned char *bytes;
    
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

- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)aSet
  options:(unsigned int)mask range:(NSRange)aRange
{
    // ENCODINGS - this code applies to the system's default encoding
    unsigned int i = 0;
    
    IMP imp = [aSet methodForSelector:@selector(characterIsMember:)];
    unsigned char *bytes = (unsigned char *)[self __compact8BitBytes];

    if (NSMaxRange(aRange) > [self cStringLength]) {
        [[[IndexOutOfRangeException alloc] initWithFormat:
            @"range %@ not in string 0x%08x of length %d",
            NSStringFromRange(aRange),
            self,
            [self cStringLength]]
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
                 ))
            {
                return NSMakeRange(i, 1);
            }
        }
    } 
    else {
        unsigned max = NSMaxRange(aRange);

        for (i = aRange.location; i < max; i++) {
            unichar c = bytes[i];

            if ((*imp)(aSet, @selector(characterIsMember:), c))
                return NSMakeRange(i, 1);
            
            if ((mask & NSCaseInsensitiveSearch) && 
                ((islower(c) &&
                  (*imp)(aSet, @selector(characterIsMember:), toupper(c))) ||
                 (isupper(c) &&
                  (*imp)(aSet, @selector(characterIsMember:), tolower(c))))
                )
            {
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
    
    if (![aString isKindOfClass:[NS8BitString class]] &&
	![aString isKindOfClass:[NSMutable8BitString class]])
	    return [super rangeOfString:aString options:mask range:aRange];
    
    if (NSMaxRange(aRange) > [self cStringLength]) {
        [[[IndexOutOfRangeException alloc] initWithFormat:
            @"range %@ not in string 0x%08x of length %d",
            NSStringFromRange(aRange),
            self,
            [self cStringLength]]
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
                unsigned int  i;
                
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
                register unsigned int i;
                
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

- (NSComparisonResult)compare:(NSString*)aString
  options:(unsigned int)mask range:(NSRange)aRange
{
    // ENCODINGS - this code applies to the system's default encoding
    unsigned char* mbytes;
    unsigned char* abytes;
    unsigned int i, n, a;

    if (![aString isKindOfClass:[NS8BitString class]] &&
	![aString isKindOfClass:[NSMutable8BitString class]])
	    return [super compare:aString options:mask range:aRange];
    
    if (NSMaxRange(aRange) > [self cStringLength]) {
        [[[IndexOutOfRangeException alloc] initWithFormat:
            @"range %@ not in string 0x%08x of length %d",
            NSStringFromRange(aRange),
            self,
            [self cStringLength]]
            raise];
    }
    
    mbytes = (unsigned char *)[self __compact8BitBytes] + aRange.location;
    abytes = (unsigned char *)[(id)aString __compact8BitBytes];
    
    a = [aString cStringLength];
    n = MIN(a, aRange.length);
    
    if (mask & NSCaseInsensitiveSearch) {
	for (i = 0; i < n; i++) {
	    unsigned char cm = islower(mbytes[i]) ? toupper(mbytes[i]):mbytes[i];
	    unsigned char ca = islower(abytes[i]) ? toupper(abytes[i]):abytes[i];

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
    unsigned char *bytes = (unsigned char *)[self __compact8BitBytes];
    unsigned hash = 0, hash2;
    int i, n = [self cStringLength];

    for(i=0; i < n; i++) {
        hash <<= 4;
	// UNICODE - must use a for independent of composed characters
        hash += bytes[i];
        if((hash2 = hash & 0xf0000000))
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
    int     mLen;
    int     aLen;
    int     i;

    if (![aString isKindOfClass:[NS8BitString class]] &&
	![aString isKindOfClass:[NSMutable8BitString class]])
	    return [super commonPrefixWithString:aString options:mask];
    
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
    int           i;
    BOOL          f      = YES;
    int           length = [self cStringLength];
    unsigned char *bytes  = (unsigned char *)[self __compact8BitBytes];
    unsigned char *chars  = MallocAtomic(sizeof(unichar)*(length+1));

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
    int           i, length;
    unsigned char *bytes;
    unsigned char *chars;
    
    length = [self cStringLength];
    bytes  = (unsigned char *)[self __compact8BitBytes];
    chars  = MallocAtomic(sizeof(unsigned char) * (length + 1));
    
    for (i = 0; i < length; i++) {
	register unsigned char c = bytes[i];
        
        chars[i] = isupper(c) ? tolower(c) : c;
    }
    chars[i] = 0;

    return AUTORELEASE([[NSOwned8BitString alloc]
                           initWithCString:(char *)chars length:length
			   copy:NO]);
}

- (NSString *)uppercaseString
{
    // ENCODINGS - this code applies to the system's default encoding
    int i;
    int length = [self cStringLength];
    unsigned char *bytes = (unsigned char *)[self __compact8BitBytes];
    unsigned char *chars = MallocAtomic(sizeof(unichar)*(length+1));

    for (i = 0; i < length; i++) {
	register unsigned char c = bytes[i];
	chars[i] = islower(c) ? toupper(c) : c;
    }
    
    chars[i] = 0;

    return AUTORELEASE([[NSOwned8BitString alloc]
                           initWithCString:(char *)chars length:length
			   copy:NO]);
}

/* Working with C strings */

- (void)getCString:(char *)buffer maxLength:(unsigned int)maxLength
  range:(NSRange)aRange remainingRange:(NSRange *)leftoverRange
{
    unsigned char *bytes  = (unsigned char *)[self __compact8BitBytes];
    unsigned int  toMove  = MIN(maxLength, aRange.length);
    unsigned int  cLength = [self cStringLength];
    
    if (NSMaxRange(aRange) > cLength) {
        [[[IndexOutOfRangeException alloc] initWithFormat:
            @"range %@ not in string 0x%08x of length %d",
            NSStringFromRange(aRange),
            self,
            cLength]
            raise];
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

- (NSString *)stringRepresentation
{
    const unsigned char *cString;
    int i, length;

    cString = (unsigned char *)[self __compact8BitBytes];
    length  = [self cStringLength];

    if (cString == NULL)    return @"\"\"";
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

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[NSMutableSimple8BitString allocWithZone:zone]
	initWithCString:[self __compact8BitBytes]
	length:[self cStringLength] copy:YES];
}

@end /* NSMutable8BitString */

@implementation NSMutableSimple8BitString

- (id)init
{
    self->cLength = 0;
    return self;
}

- (id)initWithCapacity:(unsigned int)capacity
{
    self->cLength = 0;
    self->cCapacity = capacity;
    NSZoneFree([self zone], self->cString);
    self->cString = NSZoneMallocAtomic([self zone], sizeof(char)*capacity);
    return self;
}

- (id)initWithString:(NSString *)aString
{
    // TODO: jr: move to NSTemporaryMutableString
    // TODO: hh: I do not understand this code, commented out ...
#if 0
    if ([aString isKindOfClass:[NS8BitString class]] ||
	[aString isKindOfClass:[NSMutable8BitString class]]) {
        NSMutable8BitString *str;

        str = [[NSMutable8BitString allocWithZone:[self zone]]
                                    initWithString:aString];
        RELEASE(self);
        return str;
    }
#endif
    return [self initWithCString:(char *)[aString cString]
                 length:[aString cStringLength] 
		 copy:YES];
}


- (id)initWithCString:(char *)byteString
  length:(unsigned int)length
  copy:(BOOL)flag
{
    if (flag) {
	if (cCapacity < length) {
	    lfFree(self->cString);
	    self->cString = NSZoneMallocAtomic([self zone], sizeof(char)*length);
	    self->cCapacity = length;
	}
	self->cLength = length;
	memcpy(self->cString, byteString, length);
    }
    else {
	lfFree(cString);
	cString = (unsigned char *)byteString;
	cLength = cCapacity = length;
    }
    return self;
}

- (void)dealloc
{
    lfFree(cString);
    [super dealloc];
}

- (const char *)cString
{
    unsigned char *str = MallocAtomic(sizeof(char)*(cLength + 1));

    memcpy(str, cString, cLength);
    str[cLength] = 0;
#if !LIB_FOUNDATION_BOEHM_GC
    [NSAutoreleasedPointer autoreleasePointer:str];
#endif
    return (const char *)str;
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
    if (index >= self->cLength) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"index %d out of range in string %x of length %d",
	    	index, self, self->cLength] raise];
    }
    // ENCODING
    return self->cString[index];
}

- (NSString *)substringWithRange:(NSRange)aRange
{
    Class clazz;
    
    if (NSMaxRange(aRange) > self->cLength) {
        [[[IndexOutOfRangeException alloc] initWithFormat:
            @"range %@ not in string 0x%08x of length %d",
            NSStringFromRange(aRange),
            self,
            self->cLength]
            raise];
    }

    if (aRange.length == 0)
        return @"";

    clazz = aRange.length < 255
        ? [NSShortInline8BitString class]
        : [NSInline8BitString class];
    
    return AUTORELEASE([[clazz allocForCapacity:aRange.length zone:NULL] 
                               initWithCString:
			       ((char *)self->cString + aRange.location)
                               length:aRange.length]);
}

- (char *)__compact8BitBytes
{
    return (char *)self->cString;
}

- (void)replaceCharactersInRange:(NSRange)aRange
  withString:(NSString *)aString
{
    unsigned int strLength, iFrom, iTo;
    int count;
    
    /* check range */
    if (NSMaxRange(aRange) > self->cLength) {
        [[[IndexOutOfRangeException alloc] initWithFormat:
            @"range %@ not in string 0x%08x of length %d",
            NSStringFromRange(aRange),
            self,
            self->cLength]
            raise];
    }
    
    strLength = [aString cStringLength];
    /* if range is smaller than new string enough room */
    if (aRange.length >= strLength) {
        iFrom = aRange.location + aRange.length;
        iTo   = aRange.location + strLength;
        count = self->cLength - iFrom;
        if (iFrom != iTo) {
            register int i;
            
            for (i = 0; i < count; i++)
                self->cString[iTo + i] = self->cString[iFrom + i];
        }
        self->cLength = self->cLength - aRange.length + strLength;
    }
    /* if range greater than new string */
    else {
        register int i;
        
	/* is there enough free space */
	if ((cCapacity - cLength) < (strLength - aRange.length)) {
	    /* reallocation grow strategy */
	    cCapacity += MAX(cCapacity, 
		(strLength - aRange.length) - (cCapacity - cLength));
	    cString = NSZoneRealloc(
		cString ? NSZoneFromPointer(cString) : [self zone],
		cString, sizeof(char)*cCapacity);
	}
	/* we have enough size */
	count = self->cLength - aRange.location - aRange.length;
	iFrom = self->cLength - 1;
	iTo   = self->cLength + strLength - aRange.length - 1;
	self->cLength += strLength - aRange.length;
        
	for (i = 0; i < count; i++)
	    self->cString[iTo - i] = self->cString[iFrom - i];
    }
    
    /* move string in its position */
    if (strLength) {
	NSRange range = { 0, strLength };
        
	[aString getCString:((char *)self->cString + aRange.location)
                 maxLength:strLength
                 range:range
                 remainingRange:NULL];
    }
}

@end /* NSMutableSimple8BitString */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
