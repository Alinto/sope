/* 
   NSConcreteCharacterSet.h

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

#ifndef		__NSConcreteCharacterSet_h__
#define		__NSConcreteCharacterSet_h__

#define BITMAPDATABYTES 8192*sizeof(char)
#define ISBITSET(v,n) ((((unsigned char*)v)[n/8] &   (1<<(n%8)))  ? YES : NO)
#define SETBIT(v,n)    (((unsigned char*)v)[n/8] |=  (1<<(n%8))) 
#define RESETBIT(v,n)  (((unsigned char*)v)[n/8] &= ~(1<<(n%8)))

@interface NSRangeCharacterSet : NSCharacterSet
{
    NSRange	range;
    BOOL	inverted;
}
- initWithRange:(NSRange)aRange;
- initWithRange:(NSRange)aRange inverted:(BOOL)inv;
- (NSData *)bitmapRepresentation;
- (BOOL)characterIsMember:(unichar)aCharacter;
- (NSCharacterSet *)invertedSet;
@end /* NSBitmapCharacterSet */

@interface NSStringCharacterSet : NSCharacterSet
{
    NSString*	string;
    BOOL	inverted;
}
- initWithString:(NSString*)aString;
- initWithString:(NSString*)aString inverted:(BOOL)inv;
- (NSData *)bitmapRepresentation;
- (BOOL)characterIsMember:(unichar)aCharacter;
- (NSCharacterSet *)invertedSet;
@end /* NSBitmapCharacterSet */

@interface NSBitmapCharacterSet : NSCharacterSet
{
    id   data;
    char *bytes;
    BOOL inverted;
}

- (id)initWithBitmapRepresentation:(id)data;
- (id)initWithBitmapRepresentation:(id)data inverted:(BOOL)inv;

- (NSData *)bitmapRepresentation;
- (BOOL)characterIsMember:(unichar)aCharacter;
- (NSCharacterSet *)invertedSet;

@end /* NSBitmapCharacterSet */

@interface NSMutableBitmapCharacterSet : NSMutableCharacterSet
{
    id		data;
    char*	bytes;
    BOOL	inverted;
}
- initWithBitmapRepresentation:(id)data;
- initWithBitmapRepresentation:(id)data inverted:(BOOL)inv;
- (NSData *)bitmapRepresentation;
- (BOOL)characterIsMember:(unichar)aCharacter;
- (NSCharacterSet *)invertedSet;
- (void)addCharactersInRange:(NSRange)aRange;
- (void)addCharactersInString:(NSString *)aString;
- (void)removeCharactersInRange:(NSRange)aRange;
- (void)removeCharactersInString:(NSString *)aString;
- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)otherSet;
- (void)formUnionWithCharacterSet:(NSCharacterSet *)otherSet;
- (void)invert;
@end /* NSMutableBitmapCharacterSet */

#endif		/* __NSConcreteCharacterSet_h__ */


/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
