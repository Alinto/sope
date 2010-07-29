/* 
   NSConcreteString.h

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

#ifndef  __NSConcreteString_h__
#define  __NSConcreteString_h__

#include <Foundation/NSString.h>

/*
  Abstract classes for 8 bit strings in the default encoding

  NSObject
    NSTemporaryString
      NSMutableTemporaryString
    NSString
      NS8BitString
        NSInline8BitString
        NSShortInline8BitString
        NSCharacter8BitString
        NSNonOwned8BitString
          NSOwned8BitString
            NSOwnedOpen8BitString
          NXConstantString
          NSNonOwnedOpen8BitString
            NSRange8BitString
      NSUTF16String
        NSInlineUTF16String
      NSMutableString
        NSMutable8BitString
          NSMutableSimple8BitString
*/

/*
 * Classes used to allocate concrete instances upon initWith* methods
 */

/* Used for allocating immutable instances from NSString */

@interface NSTemporaryString : NSObject
{
    NSZone *_zone;
    id     next;
}

+ (id)allocWithZone:(NSZone*)zone;
- (NSZone*)zone;

/* initWith* methods from NSString */

- (id)init;
- (id)initWithCharacters:(const unichar*)chars length:(unsigned int)length;
- (id)initWithCharactersNoCopy:(unichar*)chars length:(unsigned int)length 
  freeWhenDone:(BOOL)flag;
- (id)initWithCString:(const char*)byteString;
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
- (id)initWithData:(NSData*)data encoding:(NSStringEncoding)encoding;
- (id)initWithContentsOfFile:(NSString*)path;

@end

/* Used for allocating mutable instances from NSMutableString */

@interface NSMutableTemporaryString : NSTemporaryString
- (id)initWithCapacity:(unsigned int)capacity;
@end

/*
 * Classes for 8Bit strings
 */

/* Abstract immutable class */
@interface NS8BitString : NSString
- (void)getCharacters:(unichar*)buffer range:(NSRange)aRange;
- (NSString*)substringWithRange:(NSRange)aRange;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet*)aSet
  options:(unsigned int)mask range:(NSRange)aRange;
- (NSRange)rangeOfString:(NSString*)aString
  options:(unsigned int)mask range:(NSRange)aRange;
- (NSComparisonResult)compare:(NSString*)aString
  options:(unsigned int)mask range:(NSRange)aRange;
- (unsigned)hash;
- (NSString*)commonPrefixWithString:(NSString*)aString
  options:(unsigned int)mask;
- (NSString*)capitalizedString;
- (NSData*)dataUsingEncoding:(NSStringEncoding)encoding
  allowLossyConversion:(BOOL)flag;
- (NSString*)lowercaseString;
- (NSString*)uppercaseString;
- (void)getCString:(char*)buffer maxLength:(unsigned int)maxLength
  range:(NSRange)aRange remainingRange:(NSRange*)leftoverRange;
- (BOOL)writeToFile:(NSString*)path atomically:(BOOL)flag;
- (NSString*)stringRepresentation;
@end

@interface NS8BitString(NS8BitString)
- (id)initWithCString:(char*)byteString 
  length:(unsigned int)length copy:(BOOL)flag;
- (const char*)cString;
- (unsigned int)cStringLength;
- (char*)__compact8BitBytes;
@end

@interface NSUTF16String : NSString
@end

@interface NSInlineUTF16String : NSUTF16String
{
    int           length;
    unsigned char *cString;
    unichar       chars[1];
}
+ (id)allocForCapacity:(unsigned int)_length zone:(NSZone *)_zone;
@end

/* Abstract mutable class */
@interface NSMutable8BitString : NSMutableString
@end

@interface NSMutable8BitString(NS8BitString)
- (id)initWithCString:(char*)byteString 
  length:(unsigned int)length copy:(BOOL)flag;
- (id)initWithCapacity:(unsigned int)capacity;
- (char*)__compact8BitBytes;
@end

/* Immutable. Holds its characters in the instance, zero terminated */
@interface NSInline8BitString : NS8BitString /* final */
{
    int           cLength;
    unsigned char cString[1];
}
+ (id)allocForCapacity:(unsigned int)length zone:(NSZone*)zone;
@end

/* Immutable. Holds its characters in the instance, zero terminated */
@interface NSShortInline8BitString : NS8BitString /* final */
{
    unsigned char cLength;
    unsigned char cString[1];
}
+ (id)allocForCapacity:(unsigned int)length zone:(NSZone*)zone;
@end

/* Immutable. Holds a single character in the instance, zero terminated */
@interface NSCharacter8BitString : NS8BitString /* final */
{
    unsigned char c[2];
}
@end

/* Immutable. Holds non owned pointer characters, zero terminated */
@interface NSNonOwned8BitString : NS8BitString
{
    unsigned char *cString;
    unsigned int  cLength;
}
@end

/* Immutable. Holds owned pointer characters, zero terminated */
@interface NSOwned8BitString : NSNonOwned8BitString
@end

/* Immutable. Constant (compiler generated), zero terminated */
@interface NXConstantString : NSNonOwned8BitString
@end
@interface NSConstantString : NSNonOwned8BitString
@end

/* Immutable. Holds non owned pointer characters, not zero terminated */
@interface NSNonOwnedOpen8BitString : NSNonOwned8BitString
@end

/* Immutable. Holds owned pointer characters, not zero terminated */
@interface NSOwnedOpen8BitString : NSOwned8BitString /* final */
@end

/* Immutable. Used for substring from a constant string */
@interface NSRange8BitString : NSNonOwnedOpen8BitString /* final */
{
    NS8BitString *parent;
}
- (id)initWithString:(NSString*)aParent 
  bytes:(char*)bytes length:(unsigned int)length;
@end

/* Mutable 8 bit string, not zero terminated */
@interface NSMutableSimple8BitString : NSMutable8BitString
{
    unsigned char *cString;
    unsigned int  cLength;
    unsigned int  cCapacity;
}
@end

#endif /* __NSConcreteString_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
