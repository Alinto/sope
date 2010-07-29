/* 
   NSConcreteString.m

   Copyright (C) 2001 Helge Hess.
   All rights reserved.

   Author: Helge Hess <helge.hess@skyrix.com>

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

@implementation NSUTF16String

/* working with encodings */

- (BOOL)canBeConvertedToEncoding:(NSStringEncoding)_encoding
{
    switch(_encoding) {
        case NSUnicodeStringEncoding:
        case NSISOLatin1StringEncoding:
        case NSASCIIStringEncoding:
        case NSUTF8StringEncoding:
            return YES;
        default:
            return [super canBeConvertedToEncoding:_encoding];
    }
}

@end /* NSUTF16String */

extern int NSConvertUTF16toUTF8(unichar             **sourceStart,
                                const unichar       *sourceEnd, 
                                unsigned char       **targetStart,
                                const unsigned char *targetEnd);

@implementation NSInlineUTF16String

+ (id)allocForCapacity:(unsigned int)_capacity zone:(NSZone *)_zone
{
    NSInlineUTF16String *str;
    
    str =
        (id)NSAllocateObject(self, ((_capacity + 1) * sizeof(unichar)), _zone);
    str->length = -1;
    return str;
}

- (id)init
{
    if (self->length != -1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    self->length = 0;
    self->chars[0] = 0;
    return self;
}

- (id)initWithCharacters:(const unichar *)_chars length:(unsigned int)_length
{
    if (self->length != -1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot send %s to non-mutable instance", sel_get_name(_cmd)] 
            raise];
    }
    memcpy(self->chars, _chars, _length * sizeof(unichar));
    
    self->length = _length;
    self->chars[_length] = 0;
    return self;
}

- (void)dealloc
{
    if (self->cString) free(self->cString);
    [super dealloc];
}

/* cString */

- (const char *)cString
{
    if (self->length == 0)
        return "";
    
    if (self->cString == NULL) {
        NSData   *data;
        unsigned len;
        
        data = [self dataUsingEncoding:[NSString defaultCStringEncoding]
		     allowLossyConversion:YES];
        if (data == nil) return NULL;
        
        if ((len = [data length]) == 0)
            return "";
        
        self->cString = malloc(len + 3);
        [data getBytes:self->cString];
        self->cString[len] = '\0';
    }
    return (const char *)self->cString;
}
- (unsigned int)cStringLength
{
    const char *cstr;
    
    if ((cstr = [self cString]) != NULL)
        return strlen(cstr);
    return 0;
}

- (void)getCString:(char *)_buf
{
    strcpy(_buf, [self cString]);
}
- (void)getCString:(char *)_buf maxLength:(unsigned int)_maxLength
{
    strncpy(_buf, [self cString], _maxLength);
    _buf[_maxLength - 1] = '\0';
}
- (void)getCString:(char*)buffer maxLength:(unsigned int)maxLength
  range:(NSRange)aRange remainingRange:(NSRange *)leftoverRange
{
    unsigned int toMove, i, cLength;
    const unsigned char *cstr;
    
    cstr = (const unsigned char *)[self cString];
    
    toMove  = MIN(maxLength, aRange.length);
    cLength = [self cStringLength];
    
    if (aRange.location + aRange.length > cLength) {
	[[[IndexOutOfRangeException alloc]
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	aRange.location, aRange.length, self, cLength] raise];
    }

    if (leftoverRange) {
	leftoverRange->location = aRange.location + toMove;
	leftoverRange->length = cLength - leftoverRange->location;
    }
    for (i = 0; i < toMove; i++)
        buffer[i] = cstr[aRange.location + i];

    if (toMove < maxLength)
	buffer[toMove] = '\0';
}

/* unicode */

- (unsigned int)length
{
    return self->length;
}

- (unichar)characterAtIndex:(unsigned int)_index
{
    if ((self->length == -1) || (_index >= self->length)) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"index %d out of range in string %x of length %d",
	    	_index, self, self->length] raise];
    }
    // ENCODING
    return self->chars[_index];
}

- (void)getCharacters:(unichar *)_buffer range:(NSRange)_range
{
    if (_range.location + _range.length > self->length) {
	[[[IndexOutOfRangeException alloc] 
	    initWithFormat:@"range (%d,%d) in string %x of length %d",
	    	_range.location, _range.length, self, self->length] raise];
    }
    if (_range.length == 0)
	return;
    
    memcpy(_buffer, &(self->chars[_range.location]), 
	   _range.length * sizeof(unichar));
}

- (NSData *)dataUsingUTF8EncodingAllowLossyConversion:(BOOL)_flag
{
        unsigned char *buf;
        unsigned      bufLen;
        int           result;
        unsigned int  len;

        len = self->length;
            
        /* empty UTF16 becomes empty UTF8 .. */
        if (len == 0) return [NSData data];
        
        bufLen = (len + (len / 2));
        buf    = NSZoneMallocAtomic(NULL, bufLen + 1);
        
        do {
            unichar       *start16, *end16;
            unsigned char *start, *end;
            
            start16 = &(self->chars[0]);
            end16   = self->chars + len;
            start   = &(buf[0]);
            end     = start + bufLen;
            
            result = NSConvertUTF16toUTF8(&start16, end16, &start, end);
                
            NSAssert(result != 1, @"not enough chars in source buffer !");
                
            if (result == 2) {
                /* not enough memory in target buffer */
                bufLen *= 2;
                buf = NSZoneRealloc(NULL, buf, bufLen + 1);
            }
            else {
                len = start - buf;
                break;
            }
        }
        while (1);
	
        return [NSData dataWithBytesNoCopy:buf length:len];
}

- (NSData *)dataUsingEncoding:(NSStringEncoding)_encoding
  allowLossyConversion:(BOOL)_flag
{
    if (_encoding == NSUnicodeStringEncoding) {
        if (self->length == 0) return [NSData data];
        
        return [NSData dataWithBytes:self->chars
                       length:(self->length * sizeof(unichar))];
    }
    if (_encoding == NSUTF8StringEncoding)
        return [self dataUsingUTF8EncodingAllowLossyConversion:_flag];
    
    return [super dataUsingEncoding:_encoding allowLossyConversion:_flag];
}

- (NSStringEncoding)fastestEncoding
{
    return NSUnicodeStringEncoding;
}
- (NSStringEncoding)smallestEncoding
{
    return NSUTF8StringEncoding;
}

/* NSObject protocol */

- (NSString *)stringRepresentation
{
    /*
      an implementation of this method must quote the string for
      use in property lists.
    */
    // TODO: to be fixed (should return a unicode string-representation ...)  !!!
    return [[NSString stringWithCString:[self cString]]
	              stringRepresentation];
}

@end /* NSInlineUTF16String */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
