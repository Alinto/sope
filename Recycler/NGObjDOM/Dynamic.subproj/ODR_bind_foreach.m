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

/*
  description:

    Iterates over a list of objects. The current item is stored in the item
    binding or, if the binding is not present, as the current cursor.
  
  attributes:

    list       // array of objects to iterate through
    item       // current item in the array
    index      // current index
    identifier // unique id for element
    count      // number of times the contents will be repeated
    startIndex // first index
    qualifier  // limit set
    sortkey    // sort array using this key
    
  example:

     <var:foreach list="list" item="item">
       <var:string value="item"/>
     </var:foreach>
*/

#include <NGObjDOM/ODNodeRenderer.h>

@interface ODR_bind_foreach : ODNodeRenderer
@end

#include "WOContext+Cursor.h"
#include <DOM/DOM.h>
#include <EOControl/EOQualifier.h>
#include <EOControl/EOSortOrdering.h>
#include "common.h"

@implementation ODR_bind_foreach

- (NSArray *)_listForNode:(id)_node inContext:(WOContext *)_ctx {
  NSMutableArray *sortOrderings;
  NSArray  *array;
  id       query;
  NSString *sortkey;

  /* get list */
  
  array = [self valueFor:@"list" node:_node ctx:_ctx];
  if ([array count] == 0)
    return array;
  
  /* qualify list */
  
  if ((query = [self valueFor:@"qualifier" node:_node ctx:_ctx])) {
    if (![query isKindOfClass:[EOQualifier class]]) {
      query = [query stringValue];
      if ([query length] > 0)
        query = [EOQualifier qualifierWithQualifierFormat:[query stringValue]];
      else
        query = nil;
    }
  }
  if (query) {
    array = [array filteredArrayUsingQualifier:query];
    if ([array count] == 0)
      return array;
  }
  
  /* sort list */

  sortOrderings = nil;
  if ((sortkey = [self valueFor:@"sortkey" node:_node ctx:_ctx])) {
    NSEnumerator *keys;
    NSString *key;

    sortOrderings = [NSMutableArray arrayWithCapacity:4];
    
    keys = [[sortkey componentsSeparatedByString:@","] objectEnumerator];
    while ((key = [keys nextObject])) {
      EOSortOrdering *so;
      SEL sel = EOCompareAscending;
      
      if ([key hasPrefix:@"-"]) {
        key = [key substringFromIndex:1];
        sel = EOCompareDescending;
      }
      
      if ((so = [EOSortOrdering sortOrderingWithKey:key selector:sel]))
        [sortOrderings addObject:so];
    }
    
    if ([sortOrderings count] == 0)
      sortOrderings = nil;
  }
  if (sortOrderings)
    array = [array sortedArrayUsingKeyOrderArray:sortOrderings];

  /* return filtered and sorted list ... */
  
  return array;
}

// OWResponder

static inline void
_applyIdentifier(ODR_bind_foreach *self, id _node, id _ctx, NSString *_idx)
{
  NSArray *array;
  unsigned count;
  
  array = [self _listForNode:_node inContext:_ctx];
  count = [array count];
  
  if (count > 0) {
    unsigned i;
    BOOL hasSettableIndex;
    BOOL hasSettableItem;
    BOOL hasItem;

    if ((hasItem = [self hasAttribute:@"item" node:_node ctx:_ctx]))
      hasSettableItem = [self isSettable:@"item" node:_node ctx:_ctx];
    else
      hasSettableItem = NO;
    
    hasSettableIndex = [self isSettable:@"index" node:_node ctx:_ctx];
    
    /* find subelement for unique id */
    
    for (i = 0; i < count; i++) {
      NSString *ident;
      
      if (hasSettableIndex)
        [self setInt:i for:@"index" node:_node ctx:_ctx];
      
      if (hasSettableItem) {
        [self setValue:[array objectAtIndex:i]
              for:@"item" node:_node ctx:_ctx];
      }
      else if (!hasItem)
        /* push cursor */
        [_ctx pushCursor:[array objectAtIndex:i]];
      
      ident = [self stringFor:@"identifier" node:_node ctx:_ctx];
      
      if ([ident isEqualToString:_idx]) {
        /* found subelement with unique id */
        return;
      }
    }
    if (hasSettableItem)
      [self setValue:nil for:@"item" node:_node ctx:_ctx];
    if (hasSettableIndex)
      [self setInt:0 for:@"index" node:_node ctx:_ctx];
  }
}

static inline void
_applyIndex(ODR_bind_foreach *self, id _node, id _ctx, unsigned _i)
{
  NSArray *array;
  BOOL hasSettableItem;
  BOOL hasItem;

  if ((hasItem = [self hasAttribute:@"item" node:_node ctx:_ctx]))
    hasSettableItem = [self isSettable:@"item" node:_node ctx:_ctx];
  else
    hasSettableItem = NO;

  array = [self _listForNode:_node inContext:_ctx];
  
  if ([self isSettable:@"index" node:_node ctx:_ctx])
    [self setInt:_i for:@"index" node:_node ctx:_ctx];
  
  if (hasSettableItem) {
    unsigned count = [array count];
    
    if (_i < count)
      [self setValue:[array objectAtIndex:_i]
            for:@"item" node:_node ctx:_ctx];
    else {
      [[_ctx component] logWithFormat:
                    @"ODR_bind_foreach: array did change, index is invalid."];
      [self setValue:nil for:@"item" node:_node ctx:_ctx];
    }
  }
  else if (!hasItem) {
    /* push cursor */
    unsigned count = [array count];
    
    if (_i < count)
      [_ctx pushCursor:[array objectAtIndex:_i]];
    else {
      [[_ctx component] logWithFormat:
                    @"ODR_bind_foreach: array did change, index is invalid."];
      [_ctx pushCursor:nil];
    }
  }
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSArray  *array;
  unsigned aCount;
  unsigned goCount;

  array  = [self _listForNode:_node inContext:_ctx];
  aCount = [array count];
  
  goCount = [self hasAttribute:@"count" node:_node ctx:_ctx]
    ? [self intFor:@"count" node:_node ctx:_ctx]
    : (int)aCount;
  
  if (goCount > 0) {
    unsigned startIdx, goUntil;
    int i;
    
    startIdx = [self intFor:@"startIndex" node:_node ctx:_ctx];
    
    if (![self hasAttribute:@"identifier" node:_node ctx:_ctx]) {
      if (startIdx == 0)
        [_ctx appendZeroElementIDComponent];
      else
        [_ctx appendElementIDComponent:[self stringForInt:startIdx]];
    }
    
    if ([self hasAttribute:@"list" node:_node ctx:_ctx]) {
      goUntil = (aCount > (startIdx + goCount))
        ? startIdx + goCount
        : aCount;
    }
    else
      goUntil = startIdx + goCount;

    for (i = startIdx; i < (int)goUntil; i++) {
      _applyIndex(self, _node, _ctx, i);
      
      if ([self hasAttribute:@"identifier" node:_node ctx:_ctx]) {
        NSString *s;
        
        s = [self stringFor:@"identifier" node:_node ctx:_ctx];
        [_ctx appendElementIDComponent:s];
      }
      
      [super takeValuesForNode:_node
             fromRequest:_req
             inContext:_ctx];
      
      [_ctx popCursor];
      
      if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
        [_ctx incrementLastElementIDComponent];
      else
        [_ctx deleteLastElementIDComponent];
    }
    
    if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
      [_ctx deleteLastElementIDComponent]; // Repetition Index
  }
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  id result = nil;
  id idxId;
  
  if ((idxId  = [_ctx currentElementID])) {
    BOOL hasItem;
    int idx;
    
    hasItem = [self hasAttribute:@"item" node:_node ctx:_ctx];
    
    idx = [idxId intValue];
    [_ctx consumeElementID]; // consume index-id
    
    /* this updates the element-id path */
    [_ctx appendElementIDComponent:idxId];
    
    if ([self hasAttribute:@"identifier" node:_node ctx:_ctx])
      _applyIdentifier(self, _node, _ctx, idxId);
    else
      _applyIndex(self, _node, _ctx, idx);
    
    result = [super invokeActionForNode:_node
                    fromRequest:_req
                    inContext:_ctx];
    
    if (!hasItem) [_ctx popCursor];
    
    [_ctx deleteLastElementIDComponent];
  }
  else {
    [[_ctx session]
           logWithFormat:@"%s: %@: MISSING INDEX ID in URL !",
             __PRETTY_FUNCTION__,
             self];
  }
  return result;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  static Class NSAutoreleasePoolClass = Nil;
  NSArray     *array;
  unsigned    aCount, goCount, startIdx;
  NSAutoreleasePool *pool;
  BOOL hasId;

  if (NSAutoreleasePoolClass == Nil)
    NSAutoreleasePoolClass = [NSAutoreleasePool class];
  
  pool = [[NSAutoreleasePoolClass alloc] init];

  hasId = NO;
  
  startIdx = [self   intFor:@"startIndex" node:_node ctx:_ctx];
  goCount  = [self   intFor:@"count"      node:_node ctx:_ctx];
  array    = [self _listForNode:_node inContext:_ctx];
  aCount   = [array count];
  goCount  = (goCount) ? goCount : aCount;

#if DEBUG_REPETITION
  NSLog(@"%s: process %d items ...", __PRETTY_FUNCTION__, goCount);
#endif
  
  hasId = [self hasAttribute:@"identifier" node:_node ctx:_ctx];
  
  if (goCount > 0) {
    unsigned i, goUntil;
    BOOL hasSettableIndex = NO;
    BOOL hasSettableItem  = NO;
    BOOL hasItem          = NO;

    if (!hasId) {
      if (startIdx == 0)
        [_ctx appendZeroElementIDComponent];
      else
        [_ctx appendElementIDComponent:[self stringForInt:startIdx]];
    }

    if ([self hasAttribute:@"list" node:_node ctx:_ctx]) {
      goUntil = (aCount > (startIdx + goCount))
        ? startIdx + goCount
        : aCount;
    }
    else
      goUntil = startIdx + goCount;

    hasItem          = [self hasAttribute:@"item" node:_node ctx:_ctx];
    hasSettableIndex = [self isSettable:@"index"  node:_node ctx:_ctx];
    hasSettableItem  = [self isSettable:@"item"   node:_node ctx:_ctx];
    
    for (i = startIdx; i < goUntil; i++) {
      id ident = nil;
      
      if (hasSettableIndex)
        [self setInt:i for:@"index" node:_node ctx:_ctx];

      if (hasItem) {
        if (hasSettableItem) {
          id item;
        
          item = [array objectAtIndex:i];
#if DEBUG_REPETITION
          NSLog(@"%s: apply item: %@", __PRETTY_FUNCTION__, item);
#endif
        
          [self setValue:item for:@"item"
                node:_node ctx:_ctx];
        }
      }
      else {
        /* use cursor */
        [_ctx pushCursor:[array objectAtIndex:i]];
      }
      
      /* get identifier used for action-links */
      if (hasId) {
        /* use a unique id for subelement detection */
        ident = [self stringFor:@"identifier" node:_node ctx:_ctx];
        //  ident = [ident stringByEscapingURL]; ???
        [_ctx appendElementIDComponent:ident];
      }
      else {
        /* use repetition index fo subelement detection */
        ident = [self stringForInt:i];
      }
      
      /* append child elements */
      
      [super appendNode:(id)_node
             toResponse:(WOResponse *)_response
             inContext:(WOContext *)_ctx];
      
      /* cleanup */
      
      if (!hasItem)
        [_ctx popCursor];
      
      if (hasId)
        [_ctx deleteLastElementIDComponent];
      else
        [_ctx incrementLastElementIDComponent];
    }

    if (!hasId)
      [_ctx deleteLastElementIDComponent]; /* repetition index */
    
    if (hasSettableIndex)
      [self setInt:0 for:@"index" node:_node ctx:_ctx];
    
    if (hasSettableItem)
      [self setValue:nil for:@"item" node:_node ctx:_ctx];
  }
  RELEASE(pool);
}

@end /* ODR_bind_foreach */
