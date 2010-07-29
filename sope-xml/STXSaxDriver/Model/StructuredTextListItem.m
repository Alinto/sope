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

#include "StructuredTextListItem.h"
#include "StructuredTextList.h"
#include "common.h"

@interface NSObject(SetListPrivate)
- (void)setList:(id)_list;
@end

@implementation StructuredTextListItem

- (id)initWithTitle:(NSString *)_aTitle text:(NSString *)_aString {
  if ((self = [super init])) {
    self->_title = [_aTitle  copy];
    self->_text  = [_aString copy];
  }
  return self;
}

- (void)dealloc {
  [self->_title release];
  [self->_text  release];
  [super dealloc];
}

/* accessors */

- (NSString *)title {
  return self->_title;
}

- (NSString *)text {
  return self->_text;
}

- (void)setList:(StructuredTextList *)aList {
  self->_list = aList;
}
- (StructuredTextList *)list {
  return self->_list;
}

/* operations */

- (void)addElement:(StructuredTextBodyElement *)_item {
  if (_item == nil)
    return;
  
  [super addElement:_item];
  
  if ([_item respondsToSelector:@selector(setList:)])
    [_item setList:_list];
}

/* parsing parts */

- (NSString *)titleParsedWithDelegate:(id<StructuredTextRenderingDelegate>)_d
  inContext:(NSDictionary *)_ctx 
{
  self->_delegate = _d;
  return [self parseText:[self title] inContext:_ctx];
}

- (NSString *)textParsedWithDelegate:(id<StructuredTextRenderingDelegate>)_del
  inContext:(NSDictionary *)_ctx 
{
  self->_delegate = _del;
  return [self parseText:[self text] inContext:_ctx];
}

@end /* StructuredTextListItem */
