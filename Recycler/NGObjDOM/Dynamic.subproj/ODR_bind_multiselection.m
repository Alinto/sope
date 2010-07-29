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

#include <NGObjDOM/ODNodeRenderer.h>

/*
  attributes:
  
    list item selection
    string
    noSelectionString
    size
    name

  example:
    <script>
      var list       = [ "1", "2", "3", "4" ];
      var selections = [ "1", "4" ];
      var selection  = "2"
    </script>

    <wo:multiselection  list="list" item="item" selection="selections"/>
    <wo:singleselection list="list" item="item" selection="selection"/>
*/

@interface ODR_bind_multiselection : ODNodeRenderer
@end

@interface ODR_bind_singleselection : ODR_bind_multiselection
@end

#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_multiselection

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (BOOL)isMultiple {
  return YES;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  id        formValue = nil;
  NSString *name      = nil;

  name = [self stringFor:@"name" node:_node ctx:_ctx];
  name = (name) ? name : [_ctx elementID];

  formValue = [_req formValuesForKey:name];
    
  if ([self isSettable:@"value" node:_node ctx:_ctx])
    [self setValue:formValue for:@"value" node:_node ctx:_ctx];
  
  if ([formValue count] == 1) {
    NSArray *objects;
    id      object;
      
    objects = [self valueFor:@"list" node:_node ctx:_ctx];
      
    formValue = [formValue lastObject];
    if ([[formValue stringValue] isEqualToString:@"$"])
      object = nil; // nil item selected
    else
      object = [objects objectAtIndex:[formValue intValue]];

    if ([self isSettable:@"selection" node:_node ctx:_ctx]) {
      NSArray *sel;
        
      if ([self isSettable:@"item" node:_node ctx:_ctx])
        [self setValue:object for:@"item" node:_node ctx:_ctx];

      if (object) {
        if (![self isMultiple])
          sel = RETAIN(object);
        else
          sel = [[NSArray alloc] initWithObjects:object,nil];
      }
      else // nil item selected
        sel = nil;

      if ([self isSettable:@"selection" node:_node ctx:_ctx])
        [self setValue:sel for:@"selection" node:_node ctx:_ctx];
      RELEASE(sel); sel = nil;
    }
  }
  else if (formValue) {
    NSEnumerator   *values  = [formValue objectEnumerator];
    NSString       *v;
    NSArray        *objects = [self valueFor:@"list" node:_node ctx:_ctx];
    id             object;

    if ([self isSettable:@"selection" node:_node ctx:_ctx]) {
      NSMutableArray *sel;
      
      sel = [[NSMutableArray allocWithZone:[self zone]]
                             initWithCapacity:[formValue count]];

      while ((v = [values nextObject])) {
        object = [objects objectAtIndex:[v intValue]];

        if ([self isSettable:@"item" node:_node ctx:_ctx])
          [self setValue:object for:@"item" node:_node ctx:_ctx];
          
        if (object) [sel addObject:object];
      }

      [self setValue:sel for:@"selection" node:_node ctx:_ctx];
      RELEASE(sel); sel = nil;
    }
  }
  else {
    // nothing selected
    if ([self isSettable:@"item" node:_node ctx:_ctx])
      [self setValue:nil for:@"item" node:_node ctx:_ctx];
    if ([self isSettable:@"selection" node:_node ctx:_ctx])
      [self setValue:nil for:@"selection" node:_node ctx:_ctx];
  }
}



// ---------------------------------- ok --------------

- (void)appendOptions:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *nilStr  = nil;
  NSArray  *array   = nil;
  id       selection = nil;
  int      i, cnt;
    
  nilStr    = [self stringFor:@"noSelectionString" node:_node ctx:_ctx];
  array     = [self  valueFor:@"list"              node:_node ctx:_ctx];
  selection = [self  valueFor:@"selection"         node:_node ctx:_ctx];
  cnt       = [array count];

  if ([self isMultiple]) {
    if (![selection isKindOfClass:[NSArray class]])
      selection = [NSArray array];
  }
  
  if (nilStr) {
    [_response appendContentString:@"  <option value=\"$\">"];
    [_response appendContentHTMLString:nilStr];
    [_response appendContentString:@"\n"];
  }
    
  for (i = 0; i < cnt; i++) {
    NSString *v         = nil;
    NSString *displayV  = nil;
    id       object     = [array objectAtIndex:i];
    BOOL     isSelected;

    if ([self isSettable:@"item" node:_node ctx:_ctx])
      [self setValue:object for:@"item" node:_node ctx:_ctx];

    if (![self isMultiple])
      isSelected = selection ? [selection isEqual:object] : NO;
    else
      isSelected = selection ? [selection containsObject:object] : NO;

    v = ([self hasAttribute:@"value" node:_node ctx:_ctx])
      ? [self stringFor:@"value" node:_node ctx:_ctx]
      : [NSString stringWithFormat:@"%i", i];

    displayV = ([self hasAttribute:@"string" node:_node ctx:_ctx])
      ? [self stringFor:@"string" node:_node ctx:_ctx]
      : [object stringValue];

    if (displayV == nil) displayV = @"<nil>";

    [_response appendContentString:@"  <option value=\""];
    [_response appendContentString:v];
    [_response appendContentString:(isSelected) ? @"\" selected>" : @"\">"];
    [_response appendContentHTMLString:displayV];
    [_response appendContentString:@"\n"];
  }
}


- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (![[_ctx request] isFromClientComponent]) {
    unsigned size;
    NSString *name;

    size = [self    intFor:@"size" node:_node ctx:_ctx];
    name = [self stringFor:@"name" node:_node ctx:_ctx];
    name = (name) ? name : [_ctx elementID];

    
    [_response appendContentString:@"<select name=\""];
    [_response appendContentHTMLAttributeValue:name];
    [_response appendContentString:@"\""];

    if (size > 0) {
      [_response appendContentString:@" size=\""];
      [_response appendContentString:[NSString stringWithFormat:@"%d", size]];
      [_response appendContentCharacter:'"'];
    }
      
    if ([self isMultiple])
      [_response appendContentString:@" multiple"];
  
    [_response appendContentString: @">\n"];
  
    [self appendOptions:_node toResponse:_response inContext:_ctx];
  
    [_response appendContentString:@"</select>"];
  }
}

@end /* ODR_bind_multiselection */

@implementation ODR_bind_singleselection

- (BOOL)isMultiple {
  return NO;
}

@end /* ODR_bind_singleselection */
