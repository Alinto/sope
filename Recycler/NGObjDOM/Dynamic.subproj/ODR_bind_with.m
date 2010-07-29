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
  attributes:

    object // object to focus on

  Special objects (strings):
  
    #  - component
    #A - application
    #S - session
  
  example:
    
    <var:with js:object="FileManager().loadDocument('/blah.gif')">
      Title: <var:string value="name"/>
    </var:with>
    
    <var:with const:object="#">
      <var:string value="name"/>
    </var:with>
*/

#include <NGObjDOM/ODNodeRenderer.h>

@interface ODR_bind_with : ODNodeRenderer
@end

#include "WOContext+Cursor.h"
#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_with

- (id)_objectFromNode:(id)_node inContext:(WOContext *)_ctx {
  id obj;
  
  if (_node == nil)
    return nil;
  
  obj = [self valueFor:@"object" node:_node ctx:_ctx];
  
  if ([obj isKindOfClass:[NSString class]]) {
    if ([(NSString *)obj hasPrefix:@"#"]) {
      if ([obj isEqualToString:@"#"])
        obj = [_ctx component];
      else if ([obj isEqualToString:@"#A"])
        obj = [WOApplication application];
      else if ([obj isEqualToString:@"#S"])
        obj = [[_ctx component] session];
    }
  }
  
  return obj;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  if ([_node hasChildNodes]) {
    [_ctx pushCursor:[self _objectFromNode:_node inContext:_ctx]];
    
    [self takeValuesForChildNodes:[_node childNodes]
          fromRequest:_req
          inContext:_ctx];
    
    [_ctx popCursor];
  }
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([_domNode hasChildNodes]) {
    id result;

    [_ctx pushCursor:[self _objectFromNode:_domNode inContext:_ctx]];
    
    result = [self invokeActionForChildNodes:[_domNode childNodes]
                   fromRequest:_request
                   inContext:_ctx];
    
    [_ctx popCursor];
    
    return result;
  }
  else
    return nil;
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if ([_domNode hasChildNodes]) {
    id obj;
    
    obj = [self _objectFromNode:_domNode inContext:_ctx];
#if DEBUG
    if (obj == nil)
      NSLog(@"WARNING(%s): missing cursor object ...", __PRETTY_FUNCTION__);

    //NSLog(@"%s: using cursor %@", __PRETTY_FUNCTION__, obj);
#endif
    
    [_ctx pushCursor:obj];
#if DEBUG && 0
    NSAssert([_ctx cursor] == obj, @"cursor push failed !!");
#endif

    [self appendChildNodes:[_domNode childNodes]
          toResponse:_response
          inContext:_ctx];
    
    [_ctx popCursor];
  }
}

@end /* ODR_bind_with */
