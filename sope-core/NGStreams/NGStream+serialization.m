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

#include "config.h"

#if !defined(WIN32)
# if HAVE_SYS_TYPES_H
#  include <sys/types.h>
# endif
# if HAVE_SYS_SOCKET_H
#  include <sys/socket.h>
# endif
# if HAVE_NETINET_IN_H
#  include <netinet/in.h>
# endif
#  include <arpa/inet.h>
#endif

#include "common.h"
#include "NGStream+serialization.h"

#if NeXT_RUNTIME
#  include <objc/objc-class.h>
#endif

@implementation NGStream(serialization)

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
  context:(id<NSObjCTypeSerializationCallBack>)_callback
{
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

@end

void NGStreamSerializeObjC(id<NGStream> self,
                           const void *_value, const char *_type,
#if USE_SERIALIZER
                           id<NSObjCTypeSerializationCallBack> _callback
#else
                           id _callback
#endif
                           )
{
  switch (*_type) {
    case _C_ID:
    case _C_CLASS:
      [_callback serializeObjectAt:(id *)_value
                 ofObjCType:_type
                 intoData:(NSMutableData *)self];
      break;

    case _C_CHARPTR: {
      const char *cstr = *(char **)_value;
      int        len   = cstr ? (int)strlen(cstr) : -1;

      NGStreamSerializeObjC(self, &len, @encode(int), _callback);
      if (cstr)
        [self safeWriteBytes:cstr count:len];

      break;
    }

    case _C_ARY_B: {
      int i, offset, itemSize, count;

      count = atoi(_type + 1); // skip '[' and get dimension

      while (isdigit((int)*++_type)) ; // skip '[' and dimension
      itemSize = objc_sizeof_type(_type);

      for (i = offset = 0; i < count; i++, offset += itemSize)
        NGStreamSerializeObjC(self, (char *)_value + offset, _type, _callback);
      break;
    }
    
    case _C_STRUCT_B: {
      int offset = 0;

      while ((*_type != _C_STRUCT_E) && (*_type++ != '=')) ; // skip '<name>='

      while (YES) {
        NGStreamSerializeObjC(self, (char *)_value + offset, _type, _callback);

        offset += objc_sizeof_type(_type);
        _type  =  objc_skip_typespec(_type);
    
        if (*_type != _C_STRUCT_E) {
          int align, remainder;

          align = objc_alignof_type(_type);
          if ((remainder = offset % align))
            offset += align - remainder;
        }
        else // done with structure
          break;
      }
      break;
    }

    case _C_PTR:
      NGStreamSerializeObjC(self, *(char **)_value, _type + 1, _callback);
      break;

    case _C_CHR:
    case _C_UCHR:
      [self safeWriteBytes:_value count:1];
      break;

    case _C_SHT:
    case _C_USHT: {
      short netValue = htons(*(short *)_value);
      [self safeWriteBytes:&netValue count:2];
      break;
    }
        
    case _C_INT:
    case _C_UINT: {
      int netValue = htonl(*(int *)_value);
      [self safeWriteBytes:&netValue count:4];
      break;
    }

    case _C_LNG:
    case _C_ULNG: {
      long netValue = htonl(*(long *)_value);
      [self safeWriteBytes:&netValue count:sizeof(long)];
      break;
    }

    case _C_FLT: {
      union fconv {
        float         value;
        unsigned long ul;
      } fc;
      fc.value = *(float *)_value;
      fc.ul    = htonl(fc.ul);
      [self safeWriteBytes:&fc count:sizeof(unsigned long)];
      break;
    }
    case _C_DBL: {
      [self safeWriteBytes:_value count:8];
      break;
    }

    default:
      NSCAssert1(0, @"unsupported C type %s ..", _type);
      break;
  }
}

void NGStreamDeserializeObjC(id<NGStream> self,
                             void *_value, const char *_type,
#if USE_SERIALIZER
                             id<NSObjCTypeSerializationCallBack> _callback
#else
                             id _callback
#endif
                             ) 
{
  if ((_value == NULL) || (_type == NULL))
    return;

  switch (*_type) {
    case _C_ID:
    case _C_CLASS:
      [_callback deserializeObjectAt:(id *)_value
                 ofObjCType:_type
                 fromData:(NSData *)self
                 atCursor:0];
      break;

    case _C_CHARPTR: { // malloced C-string
      int len = -1;

      NGStreamDeserializeObjC(self, &len, @encode(int), _callback);

      if (len == -1) // NULL-string
        *(char **)_value = NULL;
      else {
        char *result = NULL;
    
#if LIB_FOUNDATION_LIBRARY
        result = NSZoneMallocAtomic(NULL, len + 1);
#else
        result = NSZoneMalloc(NULL, len + 1);
#endif
        result[len] = '\0';
    
        if (len > 0) [self safeReadBytes:result count:len];
        *(char **)_value = result;
      }
      break;
    }

    case _C_ARY_B: {
      int i, offset, itemSize, count;

      count = atoi(_type + 1); // skip '[' and get dimension

      while (isdigit((int)*++_type)) ; // skip '[' and dimension
      itemSize = objc_sizeof_type(_type);

      for (i = offset = 0; i < count; i++, offset += itemSize)
        NGStreamDeserializeObjC(self, (char *)_value + offset, _type, _callback);
      
      break;
    }
    
    case _C_STRUCT_B: {
      int offset = 0;

      while ((*_type != _C_STRUCT_E) && (*_type++ != '=')) ; // skip '<name>='

      while (YES) {
        NGStreamDeserializeObjC(self, (char *)_value + offset, _type, _callback);

        offset += objc_sizeof_type(_type);
        _type  =  objc_skip_typespec(_type);
    
        if (*_type != _C_STRUCT_E) {
          int align, remainder;

          align = objc_alignof_type(_type);
          if ((remainder = offset % align))
            offset += align - remainder;
        }
        else // done with structure
          break;
      }
      break;
    }

    case _C_PTR: {
       // skip '^', type of the value the ptr points to
      void *result = NULL;
  
      result = NSZoneMalloc(NULL, objc_sizeof_type(_type + 1));

      NGStreamDeserializeObjC(self, result, _type + 1, _callback);

      *(char **)_value = result;
      result = NULL;

      break;
    }

    case _C_CHR:
    case _C_UCHR:
      [self safeReadBytes:_value count:1];
      break;

    case _C_SHT:
    case _C_USHT:
      [self safeReadBytes:_value count:2];
      *(short *)_value = ntohs(*(short *)_value);
      break;

    case _C_INT:
    case _C_UINT:
      [self safeReadBytes:_value count:4];
      *(int *)_value = ntohl(*(int *)_value);
      break;

    case _C_LNG:
    case _C_ULNG:
      [self safeReadBytes:_value count:4];
      *(long *)_value = ntohl(*(long *)_value);
      break;

    case _C_FLT: {
      [self safeReadBytes:_value count:4];
      *(long *)_value = ntohl(*(long *)_value);
      break;
    }
    case _C_DBL: {
      [self safeReadBytes:_value count:8];
      break;
    }

    default:
      NSLog(@"unsupported C type %s ..", _type);
      break;
  }
}

void __link_NGStream_serialization(void) {
  __link_NGStream_serialization();
}
