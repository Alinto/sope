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

#include "DOMCharacterData.h"
#include "common.h"

@implementation NGDOMCharacterData

- (id)initWithString:(NSString *)_s {
  if ((self = [super init])) {
    self->data = [_s copy];
  }
  return self;
}
- (void)dealloc {
  [self->data release];
  [super dealloc];
}

/* attributes */

- (void)setData:(NSString *)_data {
  id old = self->data;
  self->data = [_data copy];
  [old release];
}
- (NSString *)data {
  return self->data;
}

- (NSUInteger)length {
  return [self->data length];
}

/* operations */

- (NSString *)substringData:(NSUInteger)_offset count:(NSUInteger)_count {
  NSRange r;

  r.location = _offset;
  r.length   = _count;
  
  return [[self data] substringWithRange:r];
}

- (void)appendData:(NSString *)_data {
  id old;
  old = self->data;
  self->data = old ? [old stringByAppendingString:_data] : _data;
  [old release];
}

- (void)insertData:(NSString *)_data offset:(NSUInteger)_offset {
  [self doesNotRecognizeSelector:_cmd];
}

- (void)deleteData:(NSUInteger)_offset count:(NSUInteger)_count {
  NSRange r;
  id new, old;
  
  r.location = _offset;
  r.length   = _count;

  new = [self->data substringWithRange:r];
  old = self->data;
  self->data = [new copy];
  [old release];
}

- (void)replaceData:(NSUInteger)_offset count:(NSUInteger)_c with:(NSString *)_s {
  [self doesNotRecognizeSelector:_cmd];
}

/* parent node */

- (void)_domNodeRegisterParentNode:(id)_parent {
  self->parent = _parent;
}
- (void)_domNodeForgetParentNode:(id)_parent {
  if (_parent == self->parent)
    /* the node's parent was deallocated */
    self->parent = nil;
}
- (id<NSObject,DOMNode>)parentNode {
  return self->parent;
}

/* QPValues */

- (NSException *)setQueryPathValue:(id)_value {
  [self setData:[_value stringValue]];
  return nil;
}
- (id)queryPathValue {
  return [self data];
}

@end /* NGDOMCharacterData(QPValues) */
