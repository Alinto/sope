/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGNet_NGActiveSocket_serialization_H__
#define __NGNet_NGActiveSocket_serialization_H__

#if !(MAC_OS_X_VERSION_10_2 <= MAC_OS_X_VERSION_MAX_ALLOWED)
#  define USE_SERIALIZER 1
#endif

#import <Foundation/NSObject.h>
#if USE_SERIALIZER
#  import <Foundation/NSSerialization.h>
#endif
#include <NGStreams/NGStream+serialization.h>
#include <NGStreams/NGActiveSocket.h>

@interface NGActiveSocket(serialization)
#if USE_SERIALIZER
  < NGSerializer >
#endif

- (void)serializeChar:(char)_value;
- (void)serializeShort:(short)_value;
- (void)serializeInt:(int)_value;
- (void)serializeLong:(long)_value;
- (void)serializeFloat:(float)_value;
- (void)serializeDouble:(double)_value;
- (void)serializeLongLong:(long long)_value;

- (char)deserializeChar;
- (short)deserializeShort;
- (int)deserializeInt;
- (long)deserializeLong;
- (float)deserializeFloat;
- (double)deserializeDouble;
- (long long)deserializeLongLong;

- (void)serializeCString:(const char *)_value;
- (char *)deserializeCString;

#if USE_SERIALIZER
- (void)serializeDataAt:(const void*)data ofObjCType:(const char*)type
  context:(id<NSObjCTypeSerializationCallBack>)_callback;
- (void)deserializeDataAt:(void *)data ofObjCType:(const char*)type
  context:(id<NSObjCTypeSerializationCallBack>)_callback;
#endif

@end

#endif /* __NGNet_NGActiveSocket_serialization_H__ */
