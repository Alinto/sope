/* 
   NSData.h

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

#ifndef __NSData_h__
#define __NSData_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSSerialization.h>

@class NSZone;
@class NSURL;
@class NSString;

@interface NSData : NSObject <NSCoding, NSCopying, NSMutableCopying>

/* Allocating and Initializing an NSData Object */
+ (id)allocWithZone:(NSZone*)zone;
+ (id)data;
+ (id)dataWithBytes:(const void*)bytes
  length:(unsigned int)length;
+ (id)dataWithBytesNoCopy:(void*)bytes
  length:(unsigned int)length;
+ (id)dataWithContentsOfFile:(NSString *)path;
+ (id)dataWithContentsOfURL:(NSURL *)_url;
+ (id)dataWithContentsOfMappedFile:(NSString *)path;
+ (id)dataWithData:(NSData *)aData;
- (id)initWithBytes:(const void*)bytes
  length:(unsigned int)length;
- (id)initWithBytesNoCopy:(void*)bytes
  length:(unsigned int)length;
- (id)initWithContentsOfFile:(NSString *)path;
- (id)initWithContentsOfURL:(NSURL *)_url;
- (id)initWithContentsOfMappedFile:(NSString *)path;
- (id)initWithData:(NSData *)data;

- (id)initWithBytesNoCopy:(void *)_bytes length:(unsigned)_length 
  freeWhenDone:(BOOL)_freeMemory;

/* Accessing Data */
- (const void*)bytes;
- (NSString *)description;
- (void)getBytes:(void *)buffer;
- (void)getBytes:(void *)buffer
	length:(unsigned int)length;
- (void)getBytes:(void *)buffer
	range:(NSRange)aRange;
- (NSData *)subdataWithRange:(NSRange)aRange;

/* Querying a Data Object */
- (BOOL)isEqualToData:(NSData*)other;
- (unsigned int)length;

/* Storing Data */
- (BOOL)writeToFile:(NSString*)path
	atomically:(BOOL)useAuxiliaryFile;

/* Deserializing Data */
- (unsigned int)deserializeAlignedBytesLengthAtCursor:(unsigned int*)cursor;
- (void)deserializeBytes:(void*)buffer
	length:(unsigned int)bytes
	atCursor:(unsigned int*)cursor;
- (void)deserializeDataAt:(void*)data
	ofObjCType:(const char*)type
	atCursor:(unsigned int*)cursor
	context:(id <NSObjCTypeSerializationCallBack>)callback;
- (int)deserializeIntAtCursor:(unsigned int*)cursor;
- (int)deserializeIntAtIndex:(unsigned int)index;
- (void)deserializeInts:(int*)intBuffer
	count:(unsigned int)numInts
	atCursor:(unsigned int*)cursor;
- (void)deserializeInts:(int*)intBuffer
	count:(unsigned int)numInts
	atIndex:(unsigned int)index;

@end /* NSData */


@interface NSMutableData : NSData

/* Creating an NSMutableData Object */
+ (id)allocWithZone:(NSZone*)zone;
+ (id)dataWithCapacity:(unsigned int)numBytes;
+ (id)dataWithLength:(unsigned int)length;
- (id)initWithCapacity:(unsigned int)capacity;
- (id)initWithLength:(unsigned int)length;

/* Adjusting Capacity */
- (void)increaseLengthBy:(unsigned int)extraLength;
- (void*)mutableBytes;
- (void)setLength:(unsigned int)length;

/* Appending Data */
- (void)appendBytes:(const void*)bytes
	length:(unsigned int)length;
- (void)appendData:(NSData*)other;

/* Modifying Data */
- (void)replaceBytesInRange:(NSRange)aRange
	withBytes:(const void*)bytes;
- (void)resetBytesInRange:(NSRange)aRange;
- (void)setData:(NSData*)aData;

/* Serializing Data */
- (void)serializeAlignedBytesLength:(unsigned int)length;
- (void)serializeDataAt:(const void*)data
	ofObjCType:(const char*)type
	context:(id <NSObjCTypeSerializationCallBack>)callback;
- (void)serializeInt:(int)value;
- (void)serializeInt:(int)value
	atIndex:(unsigned int)index;
- (void)serializeInts:(int*)intBuffer
	count:(unsigned int)numInts;
- (void)serializeInts:(int*)intBuffer
	count:(unsigned int)numInts
	atIndex:(unsigned int)index;

@end /* NSMutableData */

#endif /* __NSData_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
