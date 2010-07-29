/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#import "common.h"
#import "NGCString.h"
#import "NGMemoryAllocation.h"

@implementation NGCString

+ (id)stringWithCString:(const char *)_value length:(unsigned)_len {
  return [[[self alloc] initWithCString:_value length:_len] autorelease];
}
+ (id)stringWithCString:(const char *)_value {
  return [[[self alloc] initWithCString:_value] autorelease];
}

- (id)initWithCString:(const char *)_value length:(unsigned)_len {
  if ((self = [super init])) {
    value = NGMallocAtomic(_len + 1);
    memcpy(value, _value, _len);
    value[_len] = '\0';
    len = _len;
  }
  return self;
}
- (id)initWithCString:(const char *)_value {
  return [self initWithCString:_value length:strlen(_value)];
}

- (void)dealloc {
  NGFree(self->value); self->value = NULL;
  len = 0;
  [super dealloc];
}

// unicode

- (unsigned int)length {
  return [self cStringLength];
}

- (unichar)characterAtIndex:(unsigned int)_idx {
  return [self charAtIndex:_idx];
}

// comparing

- (BOOL)isEqual:(id)_object {
  if ([_object isKindOfClass:[NGCString class]])
    return [self isEqualToCString:_object];
  else if ([_object isKindOfClass:[NSString class]])
    return [self isEqualToString:_object];
  else
    return NO;
}
- (BOOL)isEqualToCString:(NGCString *)_cstr {
  return (strcmp([_cstr cString], value) == 0);
}
- (BOOL)isEqualToString:(NSString *)_str {
  return (strcmp([_str cString], value) == 0);
}

- (unsigned)hash {
  unsigned hash = 0, hash2;
  unsigned i;

  for(i = 0; i < len; i++) {
    hash <<= 4;
    hash += value[i];
    if((hash2 = hash & 0xf0000000))
      hash ^= (hash2 >> 24) ^ hash2;
  }
  return hash;
}

/* copying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[NGCString alloc] initWithCString:value length:len];
}
- (id)mutableCopyWithZone:(NSZone *)_zone {
  return [[NGMutableCString alloc] initWithCString:value length:len];
}

/* coding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeValueOfObjCType:@encode(unsigned int) at:&len];
  [_coder encodeArrayOfObjCType:@encode(char) count:len at:value];
}

- (id)initWithCoder:(NSCoder *)_decoder {
  char         *buffer = NULL;
  unsigned int length;
  id           cstr = nil;

  [_decoder decodeValueOfObjCType:@encode(unsigned int) at:&length];
  buffer = NGMallocAtomic(sizeof(unsigned char) * length);
  [_decoder decodeArrayOfObjCType:@encode(char) count:length at:buffer];

  cstr = [self initWithCString:buffer length:length];
  
  NGFree(buffer); buffer = NULL;
  return cstr;
}

/* getting C strings */

- (const char *)cString {
  return value;
}
- (unsigned int)cStringLength {
  return len;
}

- (void)getCString:(char *)_buffer {
  strcpy(_buffer, value);
}
- (void)getCString:(char *)_buffer maxLength:(unsigned int)_maxLength {
  unsigned int size = (_maxLength > len) ? len : _maxLength;

  strncpy(_buffer, value, size);
  _buffer[size] = '\0';
}

- (char)charAtIndex:(unsigned int)_idx {
  if (_idx >= len) {
#if LIB_FOUNDATION_LIBRARY
    NSException *exc =
      [[IndexOutOfRangeException alloc]
          initWithFormat:@"index %d out of range in string %x of length %d",
            _idx, self, len];
    [exc raise];
#else
    [NSException raise:NSRangeException
                 format:@"index %d out of range in string %x of length %d",
                   _idx, self, len];
#endif
  }
  return value[_idx];
}

// getting numeric values

- (double)doubleValue {
  if (len == 0)
    return 0.0;
  else
    return atof(value);
}
- (float)floatValue {
  return [self doubleValue];
}
- (int)intValue {
  if (len == 0)
    return 0;
  else
    return atoi(value);
}

- (NSString *)stringValue {
  return (len > 0) ? [NSString stringWithCString:value] : @"";
}

// description

- (NSString *)description {
  return [self stringValue];
}

@end

@implementation NGMutableCString

static inline void _checkCapacity(NGMutableCString *self, unsigned int _add) {
  if (self->capacity < (self->len + _add)) {
    char         *old        = self->value;
    unsigned int newCapacity = self->capacity * 2;

    if (newCapacity < (self->len + _add))
      newCapacity = self->len + _add;

    self->value = NGMallocAtomic(newCapacity + 1);
    if (old) {
      memcpy(self->value, old, self->len);
      NGFree(old);
      old = NULL;
    }
    self->value[self->len] = '\0';
  }
}

// init

- (id)initWithCString:(const char *)_value length:(unsigned)_len {
  if ((self = [super initWithCString:_value length:_len])) {
    capacity = _len;
  }
  return self;
}

// appending

- (void)appendString:(id)_str {
  _checkCapacity(self, [_str cStringLength]);
  strcat(value, [_str cString]);
}

- (void)appendCString:(const char *)_cstr {
  int l = strlen(_cstr);
  _checkCapacity(self, l);
  strcat(value, _cstr);
}

- (void)appendCString:(const char *)_cstr length:(unsigned)_len {
  _checkCapacity(self, _len);
  memcpy(&(value[len]), _cstr, _len);
  len += _len;
  value[len] = '\0';
}

// removing

- (void)removeAllContents {
  len = 0;
  value[len] = '\0';
}

@end
