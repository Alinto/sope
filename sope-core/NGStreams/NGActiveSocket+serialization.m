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

#include "NGActiveSocket+serialization.h"
#include "common.h"

@implementation NGActiveSocket(serialization)

// serialization

- (void)serializeChar:(char)_value {
  NGStreamSerializeObjC(self, &_value, @encode(char), nil);
}
- (void)serializeShort:(short)_value {
  NGStreamSerializeObjC(self, &_value, @encode(short), nil);
}
- (void)serializeInt:(int)_value {
  NGStreamSerializeObjC(self, &_value, @encode(int), nil);
}
- (void)serializeLong:(long)_value {
  NGStreamSerializeObjC(self, &_value, @encode(long), nil);
}

- (void)serializeFloat:(float)_value {
  NGStreamSerializeObjC(self, &_value, @encode(float), nil);
}
- (void)serializeDouble:(double)_value {
  NGStreamSerializeObjC(self, &_value, @encode(double), nil);
}
- (void)serializeLongLong:(long long)_value {
  NGStreamSerializeObjC(self, &_value, @encode(long long), nil);
}

- (void)serializeCString:(const char *)_value {
  NGStreamSerializeObjC(self, &_value, @encode(char *), nil);
}

#if USE_SERIALIZER
- (void)serializeDataAt:(const void*)_value ofObjCType:(const char*)_type
  context:(id<NSObjCTypeSerializationCallBack>)_callback {

  NGStreamSerializeObjC(self, _value, _type, _callback);
}
#endif

// deserialization

- (char)deserializeChar {
  char c;
  NGStreamDeserializeObjC(self, &c, @encode(char), nil);
  return c;
}
- (short)deserializeShort {
  short s;
  NGStreamDeserializeObjC(self, &s, @encode(short), nil);
  return s;
}
- (int)deserializeInt {
  int i;
  NGStreamDeserializeObjC(self, &i, @encode(int), nil);
  return i;
}
- (long)deserializeLong {
  long l;
  NGStreamDeserializeObjC(self, &l, @encode(long), nil);
  return l;
}
- (float)deserializeFloat {
  float f;
  NGStreamDeserializeObjC(self, &f, @encode(float), nil);
  return f;
}

- (double)deserializeDouble {
  double d;
  NGStreamDeserializeObjC(self, &d, @encode(double), nil);
  return d;
}
- (long long)deserializeLongLong {
  long long l;
  NGStreamDeserializeObjC(self, &l, @encode(long long), nil);
  return l;
}

- (char *)deserializeCString {
  char *result = NULL;
  NGStreamDeserializeObjC(self, &result, @encode(char *), nil);
  return result;
}

#if USE_SERIALIZER
- (void)deserializeDataAt:(void *)_value ofObjCType:(const char *)_type
  context:(id<NSObjCTypeSerializationCallBack>)_callback 
{
  NGStreamDeserializeObjC(self, _value, _type, _callback);
}
#endif

@end /* NGActiveSocket(serialization) */

void __link_NGActiveSocket_serialization(void) {
  __link_NGActiveSocket_serialization();
}
