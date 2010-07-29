/*
  Copyright (C) 2004 eXtrapola Srl

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

#include "StructuredTextHeader.h"
#include "common.h"

@implementation StructuredTextHeader

- (id)initWithString:(NSString *)_str level:(int)_level {
  if ((self = [super init])) {
    self->_text = [_str copy];
    self->level = _level;
  }
  return self;
}

- (void)dealloc {
  [self->_text release];
  [super dealloc];
}

/* accessors */

- (NSString *)text {
  return self->_text;
}

- (int)level {
  return self->level;
}

/* operations */

- (NSString *)textParsedWithDelegate:(id<StructuredTextRenderingDelegate>)_del
  inContext:(NSDictionary *)_ctx 
{
  self->_delegate = _del;
  return [self parseText:[self text] inContext:_ctx];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  /* header specific */

  if (self->_text) [ms appendFormat:@" text-len=%d", [self->_text length]];
  if (self->level) [ms appendFormat:@" level=%i",    self->level];
  
  /* common stuff */
  
  if (self->_elements) 
    [ms appendFormat:@" #elements=%d", [self->_elements count]];

  if (self->_delegate) {
    [ms appendFormat:@" delegate=0x%p<%@>", 
	  self->_delegate, NSStringFromClass([(id)self->_delegate class])];
  }
  
  if (self->runPreprocessor)
    [ms appendFormat:@" run-preprocessor"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* StructuredTextHeader */
