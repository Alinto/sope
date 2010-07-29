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

#include "WONoContentElement.h"
#include <NGObjWeb/WOComponentDefinition.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include "common.h"

@implementation WONoContentElement

- (id)initWithElementName:(NSString *)_elementName
  attributes:(NSDictionary *)_attributes
  contentElements:(NSArray *)_subElements
  componentDefinition:(WOComponentDefinition *)_cdef
{
  self->cdef    = [_cdef retain];
  self->element = [_elementName copy];
  return self;
}

- (void)dealloc {
  [self->cdef    release];
  [self->element release];
  [super dealloc];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) return;
  [_response appendContentHTMLString:@"<<missing element '"];
  [_response appendContentHTMLString:self->element];
  [_response appendContentHTMLString:@"' in component '"];
  [_response appendContentHTMLString:[self->cdef componentName]];
  [_response appendContentHTMLString:@"'>>"];
}

@end /* WONoContentElement */
