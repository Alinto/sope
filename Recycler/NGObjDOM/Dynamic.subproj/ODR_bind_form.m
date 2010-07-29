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
#include <EOControl/EOKeyValueCoding.h>

/*
   attributes:

   usage:

     <var:form const:src="/blah.sfm">
       <var:param const:name="color"    const:value="green"/>
       <var:param const:name="document" value="document"/>
     </var:form>

   form attributes
     src

   param attributes
     name
     value
     type

   NOTE: currently the context is stacked to the parent during the
   synchronizations !!!
*/

@interface ODR_bind_form : ODNodeRenderer
@end

//#define PROFILE 1

#include "common.h"
#include "used_privates.h"
#include <NGObjDOM/ODNodeRendererFactory.h>
#include <NGObjDOM/ODNamespaces.h>
#include <DOM/EDOM.h>
#include <NGObjWeb/NGObjWeb.h>

@interface _ODRBindFormTemplateWrapper : WODynamicElement
@end

@interface WOComponent(BindFormSupport)
- (void)_addChildForm:(WOComponent *)_form withId:(NSString *)_fid;
- (void)setSubComponents:(NSDictionary *)_sc;
- (NSDictionary *)_subComponents;
- (WOComponent *)childComponentWithName:(NSString *)_name;
@end

@implementation WOComponent(ChildForms)

- (void)_addChildForm:(WOComponent *)_form withId:(NSString *)_fid {
  NSMutableDictionary *msc;
  NSDictionary *sc;
  
  if (_form == nil)       return;
  if ([_fid length] == 0) return;
  
  sc = [self _subComponents];
  msc = sc
    ? [sc mutableCopy]
    : [[NSMutableDictionary alloc] initWithCapacity:4];
  
  [msc setObject:_form forKey:_fid];
  
  [self setSubComponents:msc];
  RELEASE(msc); msc = nil;
}

@end /* WOComponent(ChildForms) */

@implementation ODR_bind_form

- (WOComponent *)_childComponentForNode:(id)_node
  inContext:(WOContext *)_ctx
{
  WOComponent *form, *parent;
  NSString    *src;
  NSString    *fid;
  
  BEGIN_PROFILE;
  
  form   = nil;
  parent = [_ctx component];
  
  /* try to lookup in cache */

  fid = [self stringFor:@"id" node:_node ctx:_ctx];
  
  if ([fid length] == 0)
    fid = [self uniqueIDForNode:_node inContext:_ctx];
  
  if ([fid length] > 0) {
    fid = [NSString stringWithFormat:@"ODR_bind_form:%@", fid];
#if DEBUG && 0
    NSLog(@"FID: %@", fid);
#endif
    
    if ((form = [parent childComponentWithName:fid]))
      return form;
  }
  
  /* try to instantiate form */
  
  if ((src = [self stringFor:@"src" node:_node ctx:_ctx])) {
    //NSLog(@"%s: embed form '%@'", __PRETTY_FUNCTION__, src);
    
    PROFILE_CHECKPOINT("begin loading ..");
    
    //    NSLog(@"loading '%@' ...", src);
    form = [parent pageWithName:src];
    
    PROFILE_CHECKPOINT("and not a page form ..");
    
    if (form == nil) {
      [parent logWithFormat:@"(%@): found no subform at src '%@'",
                NSStringFromClass([parent class]), src];
    }
  }
  
  /* insert form in cache ... */
  if (form) [[_ctx component] _addChildForm:form withId:fid];
  
  END_PROFILE;
  
  return form;
}

- (WOElement *)_childContentForNode:(id)_node inContext:(WOContext *)_ctx {
  return nil;
}

- (void)_syncComponent:(WOComponent *)_form
  parent:(WOComponent *)_parent
  node:(id)_node
  syncUp:(BOOL)_syncUp
  inContext:(WOContext *)_ctx
{
  /* Watch out for correct context when calling this method ! */
  static DOMQueryPathExpression *qpexpr = nil;
  NSEnumerator *childNodes;
  id           childNode;
  
  BEGIN_PROFILE;
  
  if (_node == nil)
    return;
  
  if (qpexpr == nil)
    qpexpr = [[DOMQueryPathExpression queryPathWithString:@"-param"] retain];
  
  childNodes = _syncUp
    ? [(NSArray *)[_node childNodes] objectEnumerator]
    : [(NSArray *)[_node childNodes] reverseObjectEnumerator];
  
  while ((childNode = [childNodes nextObject])) {
    NSString *pname;
    NSString *ptype;
    id       pvalue;
    
    if ([childNode nodeType] != DOM_ELEMENT_NODE)
      continue;
    if (![[childNode tagName] isEqualToString:@"param"])
      continue;
    
    pname = [self stringFor:@"name" node:childNode ctx:_ctx];
    ptype = [self stringFor:@"type" node:childNode ctx:_ctx];
    
    if (_syncUp) {
      id attrNode;
      
      if ([ptype isEqualToString:@"in"])
        continue;
      
      attrNode = [[childNode attributes]
                             namedItem:@"value"
                             namespaceURI:XMLNS_OD_BIND];
      if (attrNode == nil) {
#if DEBUG && 0
        NSLog(@"%s: no up sync possible, missing proper value attribute ..",
              __PRETTY_FUNCTION__);
#endif
        continue;
      }
      
      pvalue = [_form valueForKey:pname];
      
#if DEBUG && 0
      [[_ctx component]
             logWithFormat:@"sync up value %@ to %@", pvalue, [attrNode value]];
#endif
      
      [_parent takeValue:pvalue forKeyPath:[attrNode value]];
    }
    else {
      if ([ptype isEqualToString:@"out"])
        continue;
      
      pvalue = [self valueFor:@"value" node:childNode ctx:_ctx];
#if DEBUG && 0
      [[_ctx component]
             logWithFormat:
               @"sync down value '%@' to '%@'", pvalue, pname];
#endif

      [_form takeValue:pvalue forKey:pname];
    }
  }
  
  END_PROFILE;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *childComponent;
  WOComponent *parentComponent;
  
  childComponent = [self _childComponentForNode:_node inContext:_ctx];
  if (childComponent == nil)
    return;

  parentComponent = [_ctx component];
  
  [self _syncComponent:childComponent
        parent:parentComponent
        node:_node
        syncUp:NO
        inContext:_ctx];
  
  [_ctx enterComponent:childComponent
        content:[self _childContentForNode:_node inContext:_ctx]];
  
  [childComponent takeValuesFromRequest:_request inContext:_ctx];

  [_ctx leaveComponent:childComponent];
  
  [self _syncComponent:childComponent
        parent:parentComponent
        node:_node
        syncUp:YES
        inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *childComponent;
  WOComponent *parentComponent;
  id result;

  BEGIN_PROFILE;

  childComponent = [self _childComponentForNode:_node inContext:_ctx];
  if (childComponent == nil) {
#if DEBUG
    [[_ctx component] debugWithFormat:@"missing child component .."];
#endif
    return nil;
  }
  
  parentComponent = [_ctx component];
  
  [self _syncComponent:childComponent
        parent:parentComponent
        node:_node
        syncUp:NO
        inContext:_ctx];
  
  [_ctx enterComponent:childComponent
        content:[self _childContentForNode:_node inContext:_ctx]];
  
#if DEBUG && 0
  [[_ctx component] debugWithFormat:@" %s\nsid=%@\neid=%@",
                      __PRETTY_FUNCTION__,
                      [_ctx senderID], [_ctx elementID]];
#endif
  
  result = [childComponent invokeActionForRequest:_request inContext:_ctx];
  
  [_ctx leaveComponent:childComponent];
  
  [self _syncComponent:childComponent
        parent:parentComponent
        node:_node
        syncUp:YES
        inContext:_ctx];

  END_PROFILE;
  
  return result;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *childComponent;
  WOComponent *parentComponent;

  BEGIN_PROFILE;
  
  childComponent = [self _childComponentForNode:_node inContext:_ctx];
  if (childComponent == nil)
    return;
  
  parentComponent = [_ctx component];

  PROFILE_CHECKPOINT("sync down ..");
  
  [self _syncComponent:childComponent
        parent:parentComponent
        node:_node
        syncUp:NO
        inContext:_ctx];

  PROFILE_CHECKPOINT("enter stack ..");
  
  [_ctx enterComponent:childComponent
        content:[self _childContentForNode:_node inContext:_ctx]];

  PROFILE_CHECKPOINT("append child ..");
  
  [childComponent appendToResponse:_response inContext:_ctx];
  
  PROFILE_CHECKPOINT("leave stack ..");
  
  [_ctx leaveComponent:childComponent];

  PROFILE_CHECKPOINT("sync up ..");
  
  [self _syncComponent:childComponent
        parent:parentComponent
        node:_node
        syncUp:YES
        inContext:_ctx];

  END_PROFILE;
}

@end /* ODR_bind_embed */

@implementation _ODRBindFormTemplateWrapper

- (id)_nodeInContext:(WOContext *)_ctx {
  return nil;
}

- (ODNodeRenderer *)rendererForNode:(id)_domNode inContext:(WOContext *)_ctx {
  id<ODNodeRendererFactory> factory;
  ODNodeRenderer *renderer = nil;

  if ((factory = [_ctx objectForKey:@"domRenderFactory"]))
    renderer = [factory rendererForNode:_domNode inContext:_ctx];

  return renderer;
}

- (void)takeValuesFromRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer = nil;
  id dom;
  
  if ((dom = [self _nodeInContext:_ctx]) == nil)
    return;

  [lrenderer takeValuesForNode:dom
             fromRequest:_request
             inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer = nil;
  id dom;
  
  if ((dom = [self _nodeInContext:_ctx]) == nil)
    return nil;
  
  return [lrenderer invokeActionForNode:dom
                    fromRequest:_request
                    inContext:_ctx];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer;
  id dom;
  
  if ((dom = [self _nodeInContext:_ctx]) == nil)
    return;

  if ((lrenderer = [self rendererForNode:dom inContext:_ctx]) == nil) {
#if DEBUG_DOM
    [cmp logWithFormat:@"did not find renderer for node %@", dom];
    [_response appendContentString:@"<!-- missing dom renderer -->"];
#endif
    return;
  }

#if DEBUG_DOM
  NSAssert(lrenderer, @"lost renderer ..");
#endif

  [lrenderer appendNode:dom
             toResponse:_response
             inContext:_ctx];

#if DEBUG_DOM
  NSAssert(_response, @"lost response ..");
  [_response appendContentString:@"<!-- renderdom-end -->"];
#endif
}

@end /* _ODRBindFormTemplateWrapper */
