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

#include "ODR_bind_groupings.h"

#include <EOControl/EOControl.h>
#include <NGObjDOM/ODNamespaces.h>
#include <DOM/EDOM.h>
#include "common.h"
#include "NGJavaScript/Core+JS.subproj/EOJavaScriptGrouping.h"

@implementation ODR_bind_groupings

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (![[_ctx objectForKey:ODR_GroupingContainerMode] boolValue])
    return;
  
  if ([self boolFor:@"disabled" node:_node ctx:_ctx])
    return;
  
  [_ctx setObject:[NSArray array] forKey:ODR_GroupingContainer];
  
  [self appendChildNodes:[_node childNodes]
        toResponse:_response
        inContext:_ctx];
}

@end /* ODR_bind_groupings */

@implementation ODR_bind_groupingset

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  EOGroupingSet *groupingSet = nil;
  id            container    = nil;
  NSString      *defaultName = nil;

  if (![[_ctx objectForKey:ODR_GroupingContainerMode] boolValue])
    return;

  if (!(container = [_ctx objectForKey:ODR_GroupingContainer]))
    return;

  groupingSet = [[EOGroupingSet alloc] init];
  if ((defaultName = [self stringFor:@"defaultName" node:_node ctx:_ctx]))
    [groupingSet setDefaultName:defaultName];

  if (([container isKindOfClass:[NSArray class]])) {
    container = [container arrayByAddingObject:groupingSet];
  }
  else if (([container isKindOfClass:[EOGroupingSet class]])) {
    NSArray *tmp;

    tmp = [container groupings];
    if (tmp == nil)
      [container setGroupings:[NSArray arrayWithObject:groupingSet]];
    else
      [container setGroupings:[tmp arrayByAddingObject:groupingSet]];
  }
  
  [_ctx setObject:groupingSet forKey:ODR_GroupingContainer];
  [self appendChildNodes:[_node childNodes]
        toResponse:_response
        inContext:_ctx];
  [_ctx setObject:container forKey:ODR_GroupingContainer];
  
  AUTORELEASE(groupingSet);
}

@end /* ODR_bind_groupingset */

@implementation ODR_bind_groupby

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  EOGrouping *grouping = nil;
  NSString   *name;
  id         value;
  id         container;

  if (![[_ctx objectForKey:ODR_GroupingContainerMode] boolValue])
    return;
  
  if (!(container = [_ctx objectForKey:ODR_GroupingContainer]))
    return;

  name = [self stringFor:@"name" node:_node ctx:_node];
  name = (name) ? name : [_ctx elementID];

  if ((value = [self stringFor:@"key" node:_node ctx:_ctx]))
    grouping = [[EOKeyGrouping alloc] initWithKey:value];
  else if ((value = [self stringFor:@"qualifier" node:_node ctx:_ctx])) {
    grouping = [[EOQualifierGrouping alloc] initWithQualifier:
                        [EOQualifier qualifierWithQualifierFormat:value]
                                            name:name];
  }
  else if ((value = [self valueFor:@"bindings" node:_node ctx:_ctx])) {
    grouping = [[EOQualifierGrouping alloc] initWithQualifier:
                        [[[EOQualifier alloc] init]
                                       qualifierWithBindings:value
                                       requiresAllVariables:NO]
                                            name:name];
  }
  else if ((value = [self valueFor:@"grouping" node:_node ctx:_ctx])) {
    if ([value isKindOfClass:[EOGrouping class]])
      ASSIGN(grouping, value);
  }
  else if ((value = [self stringFor:@"script" node:_node ctx:_ctx])) {
    static Class GroupingClass = Nil;
    
    if (GroupingClass == Nil)
      GroupingClass = NSClassFromString(@"EOJavaScriptGrouping");
    
    grouping = [[GroupingClass alloc] initWithJavaScript:value name:name];
  }
  
  if (grouping == nil)
    return;

  if ((value = [self stringFor:@"defaultName" node:_node ctx:_ctx]))
    [grouping setDefaultName:value];
  
  if ([container isKindOfClass:[EOGroupingSet class]]) {
    NSArray *tmp;

    tmp = [container groupings];
    if (tmp == nil)
      [container setGroupings:[NSArray arrayWithObject:grouping]];
    else
      [container setGroupings:[tmp arrayByAddingObject:grouping]];
  }
  else if ([container isKindOfClass:[NSArray class]]) {
    [_ctx setObject:[container arrayByAddingObject:grouping]
             forKey:ODR_GroupingContainer];
  }

  AUTORELEASE(grouping);
}

@end /* ODR_bind_groupby */
