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

#include "ODRDynamicXHTMLTag.h"
#include "common.h"
#include <EOControl/EOKeyValueCoding.h>
#include <NGScripting/NSObject+Scripting.h>
#include <NGObjDOM/ODNamespaces.h>

#if APPLE_RUNTIME || NeXT_RUNTIME
#  define sel_get_name sel_getName
#endif

@implementation ODRDynamicXHTMLTag

static NSMutableSet *nonTextTags  = nil;
static NSMutableSet *nonChildTags = nil;
static int profileRenderers = -1;
static Class NSDateClass = Nil;

+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
  if (profileRenderers == -1) {
    profileRenderers = [[[NSUserDefaults standardUserDefaults]
                                          objectForKey:@"ODProfileRenderer"]
                                          boolValue] ? 1 : 0;
  }

  if (nonChildTags == nil) {
    nonChildTags =
      [[NSMutableSet alloc] initWithObjects:
                              @"br", @"hr", @"input", nil];
  }
  if (nonTextTags == nil) {
    nonTextTags =
      [[NSMutableSet alloc] initWithObjects:
                              @"tr", @"table", @"tbody", @"thead"
                              @"head", @"html",
                              nil];
  }
}

+ (int)version {
  return [super version] + 0 /* v1 */;
}

- (NSString *)_selectNameOfNode:(id)_node inContext:(WOContext *)_ctx {
  NSString *name;
  
  if ((name = [self stringFor:@"name" node:_node ctx:_ctx]))
    return name;

  return [_ctx elementID];
}

- (NSException *)logEvaluationException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  [[_ctx component] logWithFormat:@"JS exception: %@", _exc];
  /* SKYRIX specific ... */
  [[_ctx page] takeValue:[_exc reason] forKey:@"errorString"];
  return nil;
}

- (id)invokeValueForAttributeNode:(id<DOMAttr>)_attrNode inContext:(id)_ctx {
  NSString *nsuri;

  nsuri = [_attrNode namespaceURI];
  if ([nsuri isEqualToString:XMLNS_XHTML] ||
      [nsuri isEqualToString:XMLNS_HTML40]) {
    if ([[(id<DOMAttr>)_attrNode name] hasPrefix:@"on"]) {
      /* a JS action, eg onclick */
      id scriptResult;

      NS_DURING {
        scriptResult =
          [[_ctx component] evaluateScript:[_attrNode value] language:nil];
      }
      NS_HANDLER {
        [[self logEvaluationException:localException inContext:_ctx] raise];
        scriptResult = nil;
      }
      NS_ENDHANDLER;
      
      if ([scriptResult conformsToProtocol:@protocol(WOActionResults)])
        return scriptResult;
      
      return nil;
    }
  }
  return [super invokeValueForAttributeNode:_attrNode inContext:_ctx];
}

- (id)valueForAttributeNode:(id<DOMAttr>)_attrNode inContext:(id)_ctx {
  NSString *nsuri;

  nsuri = [_attrNode namespaceURI];
  
  if ([nsuri isEqualToString:XMLNS_XHTML] ||
      [nsuri isEqualToString:XMLNS_HTML40]) {
    static NSMutableSet *hreftags = nil;

    if (hreftags == nil) {
      hreftags = [[NSMutableSet alloc] initWithCapacity:8];
      [hreftags addObject:@"src"];
      [hreftags addObject:@"href"];
    }
    
    if ([hreftags containsObject:[(id<DOMAttr>)_attrNode name]]) {
      /* a URL */
      WOResourceManager *rm;
      NSURL    *url;
      NSString *src;
      
      if ((rm = [[_ctx component] resourceManager]) == nil)
        rm = [[WOApplication application] resourceManager];

      src = [_attrNode value];
      //NSLog(@"check src: %@", src);
      
      src = [rm urlForResourceNamed:src inFramework:nil
                languages:[[_ctx session] languages]
                request:[(WOContext *)_ctx request]];
      
      //NSLog(@"  found resource: %@", src);
      
      if ([src length] == 0) {
        if ((url = [NSURL URLWithString:[_attrNode value]])) {
          /* valid, regular URL */
          src = [_attrNode value];
        }
      }
      
      return src;
    }
  }
  return [super valueForAttributeNode:_attrNode inContext:_ctx];
}

- (BOOL)includeChildNode:(id)_childNode
  ofNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  BOOL stripTextNodes;
  NSString *tagName;
  
  tagName = [_domNode tagName];
  
  if ([nonChildTags containsObject:tagName])
    /* node is not allowed to have children */
    return NO;
  
  stripTextNodes = [nonTextTags containsObject:tagName];
  
  if (stripTextNodes) {
    if ([_childNode nodeType] == DOM_TEXT_NODE)
      return NO;
    if ([_childNode nodeType] == DOM_CDATA_SECTION_NODE)
      return NO;
  }
  
  return [super includeChildNode:_childNode ofNode:_domNode inContext:_ctx];
}

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([[_domNode tagName] isEqualToString:@"input"]) {
    id formValue = nil;
    
    formValue = [_request formValueForKey:[_context elementID]];
    
    if (formValue) {
      if ([self isSettable:@"value" node:_domNode ctx:_context])
        [self setString:formValue for:@"value" node:_domNode ctx:_context];
    }
  }
  
  if ([_domNode hasChildNodes]) {
    [self takeValuesForChildNodes:[_domNode childNodes]
          fromRequest:_request
          inContext:_context];
  }
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  id       children;
  NSString *cid;
  id result;
  
  cid = [_context currentElementID];
  if ([cid length] > 0) {
    id<DOMAttr> attr;
    
    if ((attr = [_domNode attributeNode:cid namespaceURI:XMLNS_OD_ACTION])) {
      /* found a proper action attribute */
      return [[_context component] valueForKeyPath:[attr value]];
    }
  }
  
  /* pass down the hierachy */

  children = [_domNode hasChildNodes] ? [_domNode childNodes] : nil;
  
  if ([children count] == 0)
    return nil;
  
  result = [self invokeActionForChildNodes:children
                 fromRequest:_request
                 inContext:_context];
  
  return result;
}

- (void)_appendAttributesOfNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id attrs;
  id attr;
  NSTimeInterval st = 0.0;

  if ((attrs = [(id)[_domNode attributes] objectEnumerator]) == nil)
    return;
  
  if (profileRenderers)
    st = [[NSDateClass date] timeIntervalSince1970];
  
  while ((attr = [attrs nextObject])) {
    NSString *value;
    
    value = [[self valueForAttributeNode:attr inContext:_ctx] stringValue];
    
    [_response appendContentString:@" "];
    [_response appendContentString:[(id<DOMAttr>)attr name]];
    [_response appendContentString:@"=\""];
    [_response appendContentString:value];
    [_response appendContentString:@"\""];
  }

  if (profileRenderers) {
    NSTimeInterval diff;
    //int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > 0.0009) {
      //for (i = profDepth; i >= 0; i--)
      //  printf("  ");
      printf("[XHTML attrs: %s %s]: %0.3fs\n",
             [[_domNode tagName] cString],
             sel_get_name(_cmd), diff);
    }
  }
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  id       children;
  NSString *tagName;
  static unsigned profDepth = 0;
  NSTimeInterval st = 0.0;
  
  if (profileRenderers) {
    st = [[NSDateClass date] timeIntervalSince1970];
    profDepth++;
  }
  
  if ([_domNode nodeType] != DOM_ELEMENT_NODE) {
    NSLog(@"%s: WARNING incorrect renderer (invalid nodetype) for node %@",
          __PRETTY_FUNCTION__, _domNode);
    profDepth--;
    
    [super appendNode:_domNode
           toResponse:_response
           inContext:_context];
    return;
  }
  
  if (!([[_domNode namespaceURI] isEqualToString:XMLNS_XHTML] ||
        [[_domNode namespaceURI] isEqualToString:XMLNS_HTML40])) {
    /* not a HTML node */
    NSLog(@"%s: WARNING incorrect renderer (no XHTML node) for node %@",
          __PRETTY_FUNCTION__, _domNode);
    profDepth--;
    
    [super appendNode:_domNode
           toResponse:_response
           inContext:_context];
    return;
  }

  tagName = [_domNode tagName];
  
  if ([tagName isEqualToString:@"script"]) {
    NSString    *runat;
    id<DOMAttr> attr;
    
    attr  = [[_domNode attributes] 
                       namedItem:@"runat" namespaceURI:XMLNS_XHTML];
    runat = [attr value];
    if ([runat isEqualToString:@"server"]) {
      profDepth--;
      return;
    }
  }
  
  children = [_domNode hasChildNodes] ? [_domNode childNodes] : nil;
  
  [_response appendContentString:@"<"];
  [_response appendContentString:tagName];
  
  [self _appendAttributesOfNode:_domNode
        toResponse:_response
        inContext:_context];
  
  if ([children count] == 0) {
    [_response appendContentString:@" />"];
  }
  else {
    [_response appendContentString:@">"];
    
    [self appendChildNodes:children
          toResponse:_response
          inContext:_context];
    
    [_response appendContentString:@"</"];
    [_response appendContentString:tagName];
    [_response appendContentString:@">"];
  }

  if (profileRenderers) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > 0.0009) {
      for (i = profDepth; i >= 0; i--)
        printf("  ");
      printf("[xhtml: %s %s]: %0.3fs\n",
             [[_domNode tagName] cString],
             sel_get_name(_cmd), diff);
    }
    profDepth--;
  }
}

@end /* ODRDynamicXHTMLTag */
