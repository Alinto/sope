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

#include <NGObjDOM/WORenderDOM.h>
#include "ODNodeRenderer.h"
#include "common.h"

//#define DEBUG_DOM

#if NeXT_RUNTIME || APPLE_RUNTIME
#  define sel_get_name sel_getName
#endif

@interface WOContext(Privates)
- (unsigned)componentStackCount;
- (id)activeFormElement;
@end

@implementation WORenderDOM

static int profileComponents = -1;
static Class NSDateClass = Nil;

+ (void)initialize {
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
  if (profileComponents == -1) {
    profileComponents = [[[NSUserDefaults standardUserDefaults]
                                          objectForKey:@"WOProfileComponents"]
                                          boolValue] ? 1 : 0;
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_assocs
  template:(WOElement *)_templ
{
  if ((self = [super initWithName:_name associations:nil template:nil])){
    if (_templ)
      NSLog(@"WARNING(%s): contains template !", __PRETTY_FUNCTION__);
    
    self->domDocument = [[_assocs objectForKey:@"domDocument"] copy];
    self->node        = [[_assocs objectForKey:@"node"]        copy];
    self->renderer    = [[_assocs objectForKey:@"renderer"]    copy];
    self->factory     = [[_assocs objectForKey:@"factory"]     copy];
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->factory);
  RELEASE(self->node);
  RELEASE(self->renderer);
  RELEASE(self->domDocument);
  [super dealloc];
}

/* discovering renders */

- (ODNodeRenderer *)rendererForNode:(id)_domNode inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer;
  
  if ([self->node isValueSettable])
    [self->node setValue:_domNode inComponent:[_ctx component]];

  if (self->factory) {
    id<ODNodeRendererFactory> lfactory;

    if ((lfactory = [self->factory valueInComponent:[_ctx component]])) {
#if DEBUG && 0
      NSLog(@"factory: %@", lfactory);
#endif
      lrenderer = [lfactory rendererForNode:_domNode inContext:_ctx];
    }
    else
      lrenderer = nil;
  }
  else if (self->renderer)
    lrenderer = [self->renderer valueInComponent:[_ctx component]];
  else
    lrenderer = nil;

#if DEBUG && 0
  NSLog(@"lrenderer: %@", lrenderer);
#endif
  
  return lrenderer;
}

/* root level methods */

- (id)pushToCtx:(WOContext *)_ctx {
  id old;

  old = [_ctx objectForKey:@"domRenderFactory"];
  [_ctx setObject:self forKey:@"domRenderFactory"];
  return old;
}
- (void)popFromCtx:(WOContext *)_ctx old:(id)_old {
  if (_old)
    [_ctx setObject:_old forKey:@"domRenderFactory"];
  else
    [_ctx removeObjectForKey:@"domRenderFactory"];
}

- (BOOL)_requiresFormInContext:(WOContext *)_ctx
  node:(id)_domNode
  renderer:(id)_renderer
{
  if ([_ctx isInForm])
    return NO;
  
  return [_renderer requiresFormForNode:_domNode inContext:_ctx];
}

- (id)domInContext:(WOContext *)_ctx {
  return [self->domDocument valueInComponent:[_ctx component]];
}

- (void)takeValuesFromRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer;
  id   edom;
  id   old;
  BOOL doForm;
  NSTimeInterval st = 0.0;

  if (profileComponents)
    st = [[NSDateClass date] timeIntervalSince1970];
  
#if DEBUG
  if ([_ctx isInForm]) {
    NSLog(@"WARNING(%s): this element shouldn't be used in forms, it generates "
          @"it's own one.", __PRETTY_FUNCTION__);
  }
#endif

  if ((edom = [self domInContext:_ctx]) == nil)
    return;
  
  old = [self pushToCtx:_ctx];
  
  lrenderer = [self rendererForNode:edom inContext:_ctx];
  doForm = [self _requiresFormInContext:_ctx node:edom renderer:lrenderer];

  if (doForm) {
    [_ctx setInForm:YES];
  }
  
  [lrenderer takeValuesForNode:edom
             fromRequest:_request
             inContext:_ctx];

  if (doForm) {
    [_ctx setInForm:NO];
  }
  
  [self popFromCtx:_ctx old:old];
  
  if (profileComponents) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
    printf("[%s %s]: %0.3fs\n",
           "WORenderDOM", sel_get_name(_cmd), diff);
  }
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer;
  id   result;
  id   edom;
  id   old;
  BOOL doForm;
  NSTimeInterval st = 0.0;

  if (profileComponents)
    st = [[NSDateClass date] timeIntervalSince1970];

#if DEBUG
  if ([_ctx isInForm]) {
    NSLog(@"WARNING(%s): this element shouldn't be used in forms, it generates "
          @"it's own one.", __PRETTY_FUNCTION__);
  }
#endif
  
  if ((edom = [self domInContext:_ctx]) == nil)
    /* no DOM tree available */
    return nil;
  
  old = [self pushToCtx:_ctx];
  
  lrenderer = [self rendererForNode:edom inContext:_ctx];
  doForm    = [self _requiresFormInContext:_ctx node:edom renderer:lrenderer];
  
  if (doForm) {
    [_ctx setInForm:YES];
    
    if ([_ctx currentElementID] == nil) {
      id activeNode;
      
      activeNode = [_ctx activeFormElement];
      
      lrenderer = [self rendererForNode:activeNode inContext:_ctx];

      result = [lrenderer invokeActionForNode:activeNode
                          fromRequest:_request
                          inContext:_ctx];
    }
    else {
      result = [lrenderer invokeActionForNode:edom
                          fromRequest:_request
                          inContext:_ctx];
    }
    
    [_ctx setInForm:NO];
  }
  else {
    result = [lrenderer invokeActionForNode:edom
                        fromRequest:_request
                        inContext:_ctx];
  }
  
  [self popFromCtx:_ctx old:old];
  
  if (profileComponents) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
    printf("[%s %s]: %0.3fs\n",
           "WORenderDOM", sel_get_name(_cmd), diff);
  }

  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  ODNodeRenderer *lrenderer;
  WOComponent    *cmp;
  id   edom;
  id   old;
  BOOL doForm;
  NSTimeInterval st = 0.0;

  if (profileComponents)
    st = [[NSDateClass date] timeIntervalSince1970];

#if DEBUG
  if ([_ctx isInForm]) {
    NSLog(@"WARNING(%s): this element shouldn't be used in forms, it generates "
          @"it's own one.", __PRETTY_FUNCTION__);
  }
#endif
  
  cmp = [_ctx component];
  
#if DEBUG_DOM
  NSAssert(_ctx,      @"missing context ..");
  NSAssert(_response, @"missing response ..");
  NSAssert(cmp,       @"missing component ..");
  [_response appendContentString:@"<!-- renderdom-begin -->"];
#endif
  
  if ((edom = [self domInContext:_ctx]) == nil) {
#if DEBUG_DOM
    [cmp logWithFormat:@"no DOM to render .."];
    [_response appendContentString:@"<!-- missing dom -->"];
#endif
    return;
  }
  
  old = [self pushToCtx:_ctx];
  
  if ((lrenderer = [self rendererForNode:edom inContext:_ctx]) == nil) {
#if DEBUG_DOM
    [cmp logWithFormat:@"did not find renderer for node %@", edom];
    [_response appendContentString:@"<!-- missing dom renderer -->"];
#endif
    return;
  }
  
  doForm = [self _requiresFormInContext:_ctx node:edom renderer:lrenderer];
  
  if (doForm) {
    [_response appendContentString:@"<form method=\"post\" action=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];
    [_ctx setInForm:YES];
  }
  
#if DEBUG_DOM
  [cmp logWithFormat:@"render dom %@ using %@", edom, lrenderer];
  NSAssert(lrenderer, @"lost renderer ..");
#endif
  
  [lrenderer appendNode:edom
             toResponse:_response
             inContext:_ctx];
  
  if (doForm) {
    [_ctx setInForm:NO];
    [_response appendContentString:@"</form>"];
  }

#if DEBUG_DOM
  NSAssert(_response, @"lost response ..");
  [_response appendContentString:@"<!-- renderdom-end -->"];
#endif
  
  [self popFromCtx:_ctx old:old];
  
  if (profileComponents) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    for (i = [_ctx componentStackCount]; i >= 0; i--)
      printf("  ");
    printf("[%s %s]: %0.3fs (component=%s)\n",
           "WORenderDOM", sel_get_name(_cmd), diff,
           [[(WOComponent *)[_ctx component] name] cString]);
  }
}

@end /* WORenderDOM */
