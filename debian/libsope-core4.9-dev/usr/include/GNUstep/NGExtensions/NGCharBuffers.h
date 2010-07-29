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

#ifndef __NGExtensions_NGCharBuffers_H__
#define __NGExtensions_NGCharBuffers_H__

#include <string.h>
#include <ctype.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <NGExtensions/NGMemoryAllocation.h>

typedef struct {
  unsigned      capacity;
  unsigned      length;
  unsigned char increaseRatio;
  unsigned char *buffer; // zero terminated buffer
} NGCharBuffer8Struct;

typedef NGCharBuffer8Struct *NGCharBuffer8;

static inline NGCharBuffer8 NGCharBuffer8_init(NGCharBuffer8 _str,
                                               unsigned _capacity) {
  _str->capacity      = _capacity;
  _str->length        = 0;
  _str->increaseRatio = 2;
  _str->buffer        = NGMallocAtomic(_capacity);
  _str->buffer[0]     = '\0';
  return _str;
}
static inline void NGCharBuffer8_reset(NGCharBuffer8 _str) {
  if (_str) {
    _str->capacity = 0;
    _str->length   = 0;
    _str->increaseRatio = 0;
    NGFree(_str->buffer);
    _str->buffer = NULL;
  }
}

static inline NGCharBuffer8 NGCharBuffer8_new(unsigned _capacity) {
  NGCharBuffer8 str = NULL;
  str = NGMalloc(sizeof(NGCharBuffer8Struct));
  return NGCharBuffer8_init(str, _capacity);
}

static inline NGCharBuffer8 NGCharBuffer8_newWithCString(const char *_cstr) {
  NGCharBuffer8 str = NULL;
  str = NGMalloc(sizeof(NGCharBuffer8Struct));
  str = NGCharBuffer8_init(str, strlen(_cstr) + 2);
  strcpy((char *)str->buffer, _cstr);
  return str;
}

static inline void NGCharBuffer8_dealloc(NGCharBuffer8 _str) {
  if (_str) {
    NGCharBuffer8_reset(_str);
    NGFree(_str);
    _str = NULL;
  }
}

static inline void NGCharBuffer8_checkCapacity(NGCharBuffer8 _str,
                                               unsigned _needed) {
  if (_str->capacity < (_str->length + _needed + 1)) {
    // increase size
    unsigned char *oldBuffer = _str->buffer;

    _str->capacity *= _str->increaseRatio;
    if (_str->capacity < (_str->length + _needed + 1))
      _str->capacity += _needed + 1;
    
    _str->buffer   = NGMallocAtomic(_str->capacity + 2);
    memcpy(_str->buffer, oldBuffer, (_str->length + 1));
    NGFree(oldBuffer);
    oldBuffer = NULL;
  }
}

static inline void NGCharBuffer8_addChar(NGCharBuffer8 _str, unsigned char _c) {
  NGCharBuffer8_checkCapacity(_str, 1);

  _str->buffer[_str->length] = _c;
  (_str->length)++;
  _str->buffer[_str->length] = '\0';
}

static inline void NGCharBuffer8_addCString(NGCharBuffer8 _str, char *_cstr) {
  unsigned len;
  
  if (_cstr == NULL)
    return;

  len = strlen(_cstr);
  NGCharBuffer8_checkCapacity(_str, len);
  strcat((char *)_str->buffer, _cstr);
  _str->length += len;
}

static inline void NGCharBuffer8_removeContents(NGCharBuffer8 _str) {
  _str->length = 0;
  _str->buffer[0] = '\0';
}

static inline NSString *NGCharBuffer8_makeStringAndDealloc(NGCharBuffer8 _str){
  NSString *str;
  
  if (_str == NULL)
    return nil;

  str = [NSString stringWithCString:(char *)_str->buffer length:_str->length];
  NSCAssert3(strlen((char *)_str->buffer) == _str->length,
	     @"length of cstring(%s) and the buffer do not match (%i vs %i)",
	     _str->buffer, strlen((char *)_str->buffer), _str->length);

  NGCharBuffer8_dealloc(_str); _str = NULL;
  return str;
}

static inline void NGCharBuffer8_stripTrailingSpaces(NGCharBuffer8 _str) {
  if (_str == NULL)
    return;
  else if (_str->length == 0)
    return;
  else {
    while (_str->length > 0) {
      unsigned char c = _str->buffer[_str->length - 1];

      if (isspace((int)c) || (c == '\n') || (c == '\r')) {
        (_str->length)--;
      }
      else {
        break;
      }
    }
    _str->buffer[_str->length] = '\0';
  }
}

#endif /* __NGExtensions_NGCharBuffers_H__ */
