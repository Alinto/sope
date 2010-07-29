/* 
   NSCoder.h

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

#ifndef __NSCoder_h__
#define __NSCoder_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSData;

@interface NSCoder : NSObject

/* Encoding Data */
- (void)encodeArrayOfObjCType:(const char*)types	
	count:(unsigned int)count
	at:(const void*)array;
- (void)encodeBycopyObject:(id)anObject;
- (void)encodeConditionalObject:(id)anObject;
- (void)encodeDataObject:(NSData*)data;
- (void)encodeObject:(id)anObject;
- (void)encodePropertyList:(id)aPropertyList;
- (void)encodeRootObject:(id)rootObject;
- (void)encodeValueOfObjCType:(const char*)type
	at:(const void*)address;
- (void)encodeValuesOfObjCTypes:(const char*)types, ...;

/* Encoding geometry types */
- (void)encodePoint:(NSPoint)point;
- (void)encodeSize:(NSSize)size;
- (void)encodeRect:(NSRect)rect;

/* Decoding Data */
- (void)decodeArrayOfObjCType:(const char*)types
	count:(unsigned)count
	at:(void*)address;
- (NSData*)decodeDataObject;
- (id)decodeObject;
- (id)decodePropertyList;
- (void)decodeValueOfObjCType:(const char*)type
	at:(void*)address;
- (void)decodeValuesOfObjCTypes:(const char*)types, ...;

/* Decoding geometry types */
- (NSPoint)decodePoint;
- (NSSize)decodeSize;
- (NSRect)decodeRect;

/* Managing Zones */
- (NSZone*)objectZone;
- (void)setObjectZone:(NSZone*)zone;

/* Getting a Version */
- (unsigned int)systemVersion;
- (unsigned int)versionForClassName:(NSString*)className;

@end

#endif /* __NSCoder_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
