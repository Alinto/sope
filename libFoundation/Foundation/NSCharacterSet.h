/* 
   NSCharacterSet.h

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

#ifndef __NSCharacterSet_h__
#define __NSCharacterSet_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

/*
 * NSCharacterSet
 */

@interface NSCharacterSet : NSObject

/* Creating a Standard Character Set */

+ (NSCharacterSet *)alphanumericCharacterSet;
+ (NSCharacterSet *)controlCharacterSet;
+ (NSCharacterSet *)decimalDigitCharacterSet;
+ (NSCharacterSet *)decomposableCharacterSet;
+ (NSCharacterSet *)illegalCharacterSet;
+ (NSCharacterSet *)letterCharacterSet;
+ (NSCharacterSet *)lowercaseLetterCharacterSet;
+ (NSCharacterSet *)nonBaseCharacterSet;
+ (NSCharacterSet *)uppercaseLetterCharacterSet;
+ (NSCharacterSet *)whitespaceAndNewlineCharacterSet;
+ (NSCharacterSet *)whitespaceCharacterSet;
+ (NSCharacterSet *)punctuationCharacterSet;
+ (NSCharacterSet *)emptyCharacterSet;

/* Creating a Custom Character Set */

+ (NSCharacterSet *)characterSetWithContentsOfFile:(NSString*)fileName;
+ (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData*)data;
+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString*)aString;
+ (NSCharacterSet *)characterSetWithRange:(NSRange)aRange;

/* Getting a Binary Representation */

- (NSData *)bitmapRepresentation;

/* Testing Set Membership */

- (BOOL)characterIsMember:(unichar)aCharacter;

/* Inverting a Character Set */

- (NSCharacterSet *)invertedSet;

@end /* NSCharacterSet */

/*
 * NSMutableCharacterSet
 */

@interface NSMutableCharacterSet : NSCharacterSet

/* Adding and Removing Characters */

- (void)addCharactersInRange:(NSRange)aRange;
- (void)addCharactersInString:(NSString*)aString;
- (void)removeCharactersInRange:(NSRange)aRange;
- (void)removeCharactersInString:(NSString*)aString;

/* Combining Character Sets */

- (void)formIntersectionWithCharacterSet:(NSCharacterSet*)otherSet;
- (void)formUnionWithCharacterSet:(NSCharacterSet*)otherSet;

/* Inverting a Character Set */

- (void)invert;

@end /* NSMutableCharacterSet */

/* constants */

enum { NSOpenStepUnicodeReservedBase = 0xF400 };

#endif /* __NSCharacterSet_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
