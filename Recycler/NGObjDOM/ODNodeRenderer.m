/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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
#include <NGObjDOM/ODNodeRendererFactory.h>
#include <NGObjDOM/ODNamespaces.h>
#include "common.h"

//#define WITH_EXCEPTION_HANDLER 1
#if NeXT_RUNTIME || APPLE_RUNTIME
#  define sel_get_name sel_getName
#endif

@implementation ODNodeRenderer

static int    profileRenderers = -1;
static double profRenderMin = 0.0009;
static Class NSDateClass = Nil;

+ (void)initialize {
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
  
  if (profileRenderers == -1) {
    id tmp;
    
    profileRenderers = [[[NSUserDefaults standardUserDefaults]
                                          objectForKey:@"ODProfileRenderer"]
                                          boolValue] ? 1 : 0;
    
    if ((tmp = [[NSUserDefaults standardUserDefaults]
                                objectForKey:@"ODProfileRendererMin"])) {
      double d = [tmp doubleValue];
      
      if (d > profRenderMin) {
        profRenderMin = d;
        if (profileRenderers)
          NSLog(@"profRenderMin: %0.3fs", profRenderMin);
      }
    }
  }
}

+ (int)version {
  return 1;
}

- (NSString *)_idForNode:(id)_node {
  if ([_node nodeType] == DOM_ELEMENT_NODE) {
    NSString *s;

    if ((s = [_node attribute:@"id" namespaceURI:@"*"]))
      return s;
    
    return [_node tagName];
  }
  
  return [_node nodeName];
}

/* renderer lookup */

- (ODNodeRenderer *)rendererForNode:(id)_domNode inContext:(WOContext *)_ctx {
  id<ODNodeRendererFactory> factory;
  ODNodeRenderer *renderer = nil;
  NSTimeInterval st = 0.0;

  if (profileRenderers)
    st = [[NSDateClass date] timeIntervalSince1970];
  
  if ((factory = [_ctx objectForKey:@"domRenderFactory"]))
    renderer = [factory rendererForNode:_domNode inContext:_ctx];
  
  if (profileRenderers) {
    NSTimeInterval diff;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > profRenderMin) {
      printf("[renderer lookup: %s %s]: %0.3fs id='%s'\n",
             [[_domNode nodeName] cString],
             sel_get_name(_cmd), diff,
             [[self _idForNode:_domNode] cString]);
    }
  }
  
  return renderer;
}

/* request phase operations on children */

- (void)takeValuesForChildNodes:(id)_nodeList
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  id children;
  id child;
  NSTimeInterval st = 0.0;
  static int profDepth = 0;

  if (profileRenderers) {
    st = [[NSDateClass date] timeIntervalSince1970];
    profDepth++;
  }
  
  if ([_nodeList count] == 0) {
    profDepth--;
    return;
  }
  
  [_ctx appendZeroElementIDComponent];
  
  children = [_nodeList objectEnumerator];
  while ((child = [children nextObject])) {
    if ([self includeChildNode:child ofNode:[child parentNode] inContext:_ctx]) {
      ODNodeRenderer *renderer;
      
      if ((renderer = [self rendererForNode:child inContext:_ctx])) {
        [renderer takeValuesForNode:child
                  fromRequest:_request
                  inContext:_ctx];
      }
    }    
    [_ctx incrementLastElementIDComponent];
  }
  
  [_ctx deleteLastElementIDComponent];
  
  if (profileRenderers) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > profRenderMin) {
      id dn;

      dn = [[_nodeList lastObject] parentNode];
      
      for (i = profDepth; i >= 0; i--)
        printf("  ");
      printf("[list: %s %s]: %0.3fs '%s'\n",
             [[dn nodeName] cString],
             sel_get_name(_cmd), diff,
             [[self _idForNode:dn] cString]);
    }
    profDepth--;
  }
}

- (id)invokeActionForChildNodes:(id)_nodeList
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *idxId;
  id result;
  NSTimeInterval st = 0.0;
  static int profDepth = 0;

  if (profileRenderers) {
    st = [[NSDateClass date] timeIntervalSince1970];
    profDepth++;
  }
  
  if ([_nodeList count] == 0) {
    profDepth--;
#if DEBUG && 0
    NSLog(@"%s: no child nodes to invoke upon ..", __PRETTY_FUNCTION__);
#endif
    return nil;
  }
  
  if ((idxId  = [_ctx currentElementID])) {
    id node;
    unsigned count;
    
    count = [_nodeList count];
    
    if (isdigit([idxId characterAtIndex:0])) {
      /* lookup by index */
      int idx;
      idx = [idxId intValue];
      
      if (idx >= count) {
        NSLog(@"%s: ERROR, click index is out of range "
              @"(idx=%i, count=%d, eid=%@, sid=%@)",
              __PRETTY_FUNCTION__, idx, count,
              [_ctx elementID], [_ctx senderID]);
        node = nil;
      }
      else if ((node = [_nodeList objectAtIndex:idx]) == nil) {
#if DEBUG
        NSLog(@"%s: ERROR, did not find node at index %i (tag=%@, list=%@) ..",
              __PRETTY_FUNCTION__, idx,
              [[_nodeList parentNode] nodeName], _nodeList);
#endif
      }
    }
    else {
      /* lookup by name */
      NSLog(@"%s: ERROR, LOOK FOR NAME %@ ..", __PRETTY_FUNCTION__, idxId);
      node = nil;
    }
    
    [_ctx consumeElementID]; // consume index-id
    
    /* this updates the element-id path */
    [_ctx appendElementIDComponent:idxId];

#if DEBUG && 0
    NSLog(@"%s: invoke action on node:\n  %@\n  id=%@", __PRETTY_FUNCTION__,
          node, [_ctx currentElementID]);
#endif
    
    result = [[self rendererForNode:node inContext:_ctx]
                    invokeActionForNode:node
                    fromRequest:_request
                    inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent];
  }
  else {
    [[_ctx session]
           logWithFormat:
             @"%s: %@: \n"
             @"    MISSING INDEX ID in URL\n    eid: %@\n    nodelist: %@ !",
             __PRETTY_FUNCTION__,
             self, [_ctx elementID], _nodeList];
    result = nil;
  }
  
  if (profileRenderers) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > profRenderMin) {
      for (i = profDepth; i >= 0; i--)
        printf("  ");
      printf("[list: %s %s]: %0.3fs\n",
             [[[[_nodeList lastObject] parentNode] nodeName] cString],
             sel_get_name(_cmd), diff);
    }
    profDepth--;
  }
  
  return result;
}

- (void)appendChildNodes:(id)_nodeList
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id children;
  id child, parent;
  static unsigned profDepth = 0;
  NSTimeInterval st = 0.0;

  if (profileRenderers) {
    st = [[NSDateClass date] timeIntervalSince1970];
    profDepth++;
  }
  
  if ([_nodeList count] == 0) {
    profDepth--;
    return;
  }
  
  [_ctx appendZeroElementIDComponent];

  parent   = nil;
  children = [_nodeList objectEnumerator];
  while ((child = [children nextObject])) {
    if (parent == nil) parent = [child parentNode];
    
    if ([self includeChildNode:child ofNode:parent inContext:_ctx]) {
      ODNodeRenderer *renderer;
      NSTimeInterval st = 0.0;

      if (profileRenderers) {
        st = [[NSDateClass date] timeIntervalSince1970];
        profDepth++;
      }
      
      renderer = [self rendererForNode:child inContext:_ctx];
      
      [renderer appendNode:child
                toResponse:_response
                inContext:_ctx];
      
      if (profileRenderers) {
        NSTimeInterval diff;
        int i;
        diff = [[NSDateClass date] timeIntervalSince1970] - st;
        if (diff > profRenderMin) {
          for (i = profDepth; i >= 0; i--)
            printf("  ");
          printf("[child: %s %s]: %0.3fs '%s'\n",
                 [[child nodeName] cString],
                 sel_get_name(_cmd), diff,
                 [[self _idForNode:child] cString]);
        }
        profDepth--;
      }
    }
    [_ctx incrementLastElementIDComponent];
  }
  
  [_ctx deleteLastElementIDComponent];

  
  if (profileRenderers) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > profRenderMin) {
      id dn;
      
      dn = [[_nodeList lastObject] parentNode];
      
      for (i = profDepth; i >= 0; i--)
        printf("  ");
      printf("[list: %s %s]: %0.3fs '%s'\n",
             [[dn nodeName] cString],
             sel_get_name(_cmd), diff,
             [[self _idForNode:dn] cString]);
    }
    profDepth--;
  }
}

/* the three WO request phase operations */

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
#if DEBUG && 0
  NSLog(@"take values for node: %@", _domNode);
#endif

#if WITH_EXCEPTION_HANDLER
  NS_DURING {
    if ([_domNode hasChildNodes]) {
      [self takeValuesForChildNodes:[_domNode childNodes]
            fromRequest:_request
            inContext:_context];
    }
  }
  NS_HANDLER {
    fprintf(stderr, "%s\n", [[localException description] cString]);
    abort();
  }
  NS_ENDHANDLER;
#else
  if ([_domNode hasChildNodes]) {
    [self takeValuesForChildNodes:[_domNode childNodes]
          fromRequest:_request
          inContext:_context];
  }
#endif
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([_domNode hasChildNodes]) {
    return [self invokeActionForChildNodes:[_domNode childNodes]
                 fromRequest:_request
                 inContext:_context];
  }
  else {
#if DEBUG
    NSLog(@"%s: node %@ has no child nodes:\n  sid=%@\n  eid=%@",
          __PRETTY_FUNCTION__, _domNode,
          [_context senderID], [_context elementID]);
#endif
    return nil;
  }
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  if ([_domNode hasChildNodes]) {
    [self appendChildNodes:[_domNode childNodes]
          toResponse:_response
          inContext:_context];
  }
}

/* requires HTML form */

- (BOOL)requiresFormForChildNodes:(id)_nodeList inContext:(WOContext *)_ctx {
  id children;
  id child;
  
  if ([_nodeList count] == 0)
    return NO;
  
  if ([_ctx isInForm])
    return NO;
  
  children = [_nodeList objectEnumerator];
  
  while ((child = [children nextObject])) {
    if ([self includeChildNode:child ofNode:[child parentNode] inContext:_ctx]) {
      ODNodeRenderer *renderer;
      
      if ((renderer = [self rendererForNode:child inContext:_ctx])) {
        if ([renderer requiresFormForNode:child inContext:_ctx])
          return YES;
      }
    }
  }
  return NO;
}

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  if ([_domNode hasChildNodes]) {
    return [self requiresFormForChildNodes:[_domNode childNodes]
                 inContext:_ctx];
  }
  else
    return NO;
}

/* generating node ids unique in DOM tree */

- (NSString *)uniqueIDForNode:(id)_node inContext:(WOContext *)_ctx {
  NSMutableArray  *nodePath;
  NSMutableString *uid;
  NSEnumerator    *topDown;
  id   node, parent;
  BOOL isFirst;
  
  if (_node == nil) return nil;
  
  nodePath = [NSMutableArray arrayWithCapacity:16];
  
  /* collect all parent nodes in bottom-up form */
  
  for (node = _node; node; node = [node parentNode])
    [nodePath addObject:node];
  
  /* generate ID */
  
  uid     = [NSMutableString stringWithCapacity:64];
  topDown = [nodePath reverseObjectEnumerator];
  isFirst = YES;
  parent  = nil;

  for (isFirst = YES; (node = [topDown nextObject]); parent = node) {
    if (!isFirst) {
      NSArray  *children;
      unsigned i, count;
      
      [uid appendString:@"."];
      
      /* determine index of _node */

      children = (NSArray *)[parent childNodes];
      for (i = 0, count = [children count]; i < count; i++) {
        if ([children objectAtIndex:i] == node)
          break;
      }
      [uid appendFormat:@"%d", i];
    }
    else {
      [uid appendString:@"R"];
      isFirst = NO;
    }
  }
  
  return [[uid copy] autorelease];
}

/* selecting children */

- (BOOL)includeChildNode:(id)_childNode
  ofNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  /* check 'if' attribute .. */

  if ([_childNode nodeType] != DOM_ELEMENT_NODE)
     return YES;
  
  if ([_childNode hasAttribute:@"if" namespaceURI:@"*"])
    return [self boolFor:@"if" node:_childNode ctx:_ctx];
  
  if ([_childNode hasAttribute:@"ifnot" namespaceURI:@"*"])
    return [self boolFor:@"ifnot" node:_childNode ctx:_ctx] ? NO : YES;
  
  return YES;
}

@end /* ODNodeRenderer */
