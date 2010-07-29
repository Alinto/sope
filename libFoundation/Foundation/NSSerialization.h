/* 
   NSSerialization.h

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

#ifndef __NSSerialization_h__
#define __NSSerialization_h__

#include <objc/objc.h>
#include <Foundation/NSObject.h>

@class NSData;
@class NSMutableData;

@protocol NSObjCTypeSerializationCallBack

- (void)deserializeObjectAt:(id *)object
  ofObjCType:(const char *)type
  fromData:(NSData *)data
  atCursor:(unsigned int *)cursor;

- (void)serializeObjectAt:(id *)object
  ofObjCType:(const char *)type
  intoData:(NSMutableData *)data;

@end

@interface NSSerializer : NSObject

+ (void)serializePropertyList:(id)_plist intoData:(NSMutableData *)_data;
+ (NSData *)serializePropertyList:(id)_plist;

@end

@interface NSDeserializer : NSObject

+ (id)deserializePropertyListFromData:(NSData *)_data
  atCursor:(unsigned *)_cursor
  mutableContainers:(BOOL)_flag;

+ (id)deserializePropertyListLazilyFromData:(NSData *)_data
  atCursor:(unsigned *)_cursor
  length:(unsigned)_len
  mutableContainers:(BOOL)_flag;

+ (id)deserializePropertyListFromData:(NSData *)_data
  mutableContainers:(BOOL)_flag;

@end

#endif /* __NSSerialization_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
