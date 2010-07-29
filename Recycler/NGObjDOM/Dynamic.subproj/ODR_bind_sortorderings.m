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

#include "ODR_bind_sortorderings.h"

#import <EOControl/EOControl.h>
#include <NGObjDOM/ODNamespaces.h>
#include <DOM/EDOM.h>
#include "common.h"


@implementation ODR_bind_sortorderings
- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (![[_ctx objectForKey:ODR_SortOrderingContainerMode] boolValue])
    return;
  
  if ([self boolFor:@"disabled" node:_node ctx:_ctx])
    return;
  
  [_ctx setObject:[NSArray array] forKey:ODR_SortOrderingContainer];
  
  [self appendChildNodes:[_node childNodes]
        toResponse:_response
        inContext:_ctx];
}

@end

@implementation ODR_bind_sortordering

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  EOSortOrdering *so        = nil;
  NSArray        *orderings = nil;
  NSString       *sortedKey = nil;
  BOOL           isDesc;
  SEL            sel;

  if (![[_ctx objectForKey:ODR_SortOrderingContainerMode] boolValue])
    return;

  if (!(orderings = [_ctx objectForKey:ODR_SortOrderingContainer]))
    return;

  if (!(sortedKey = [self stringFor:@"key"  node:_node ctx:_ctx]))
    return;

  isDesc = [self boolFor:@"isdescending" node:_node ctx:_ctx];

  sel       = (isDesc) ? EOCompareDescending : EOCompareAscending;
  so        = [EOSortOrdering sortOrderingWithKey:sortedKey  selector:sel];
  orderings = [orderings arrayByAddingObject:so];
  
  [_ctx setObject:orderings forKey:ODR_SortOrderingContainer];
}

@end
