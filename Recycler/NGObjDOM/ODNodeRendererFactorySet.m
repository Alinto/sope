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

#include <NGObjDOM/ODNodeRendererFactorySet.h>

@interface _ODNodeRendererFactorySetEntry : NSObject
{
@public
  ODNodeRendererFactory *factory;
  EOQualifier *qualifier;
  NSString    *namespaceURI;
  NSString    *tagName;
}

- (BOOL)matchesNode:(id)_node;
- (ODNodeRendererFactory *)nodeRendererFactory;

@end

#include <NGObjDOM/ODRNodeText.h>
#include <NGObjDOM/ODRGenericTag.h>
#include "common.h"
#include <EOControl/EOQualifier.h>

@implementation ODNodeRendererFactorySet

+ (int)version {
  return 1;
}

- (void)dealloc {
  RELEASE(self->subfactories);
  RELEASE(self->cache);
  [super dealloc];
}

- (void)flushCache {
  [self->cache removeAllObjects];
}

/* registry */

- (void)registerFactory:(id<NSObject,ODNodeRendererFactory>)_factory
  forNodeQualifier:(EOQualifier *)_qualifier
{
  _ODNodeRendererFactorySetEntry *entry;

#if DEBUG
  if (![_factory conformsToProtocol:@protocol(ODNodeRendererFactory)]) {
    NSLog(@"WARNING(%s): node-factory %@ to be registered, doesn't implement "
          @"the ODNodeRendererFactory protocol !",
          __PRETTY_FUNCTION__, _factory);
  }
#endif
  
  [self flushCache];
  
  entry = [[_ODNodeRendererFactorySetEntry alloc] init];
  entry->factory   = RETAIN(_factory);
  entry->qualifier = RETAIN(_qualifier);

  if (self->subfactories == nil)
    self->subfactories = [[NSMutableArray alloc] initWithCapacity:4];
  [self->subfactories addObject:entry];
  RELEASE(entry);
}

- (void)registerFactory:(id<NSObject,ODNodeRendererFactory>)_factory
  forNamespaceURI:(NSString *)_namespaceURI
  tagName:(NSString *)_tagName
{
  _ODNodeRendererFactorySetEntry *entry;
  
#if DEBUG
  if (![_factory conformsToProtocol:@protocol(ODNodeRendererFactory)]) {
    NSLog(@"WARNING(%s): node-factory %@ to be registered, doesn't implement "
          @"the ODNodeRendererFactory protocol !",
          __PRETTY_FUNCTION__, _factory);
  }
#endif

  [self flushCache];
  
  entry = [[_ODNodeRendererFactorySetEntry alloc] init];
  entry->factory      = RETAIN(_factory);
  entry->namespaceURI = [_namespaceURI copy];
  entry->tagName      = [_tagName copy];
  
  if (self->subfactories == nil)
    self->subfactories = [[NSMutableArray alloc] initWithCapacity:4];
  [self->subfactories addObject:entry];
  RELEASE(entry);
}

- (void)registerFactory:(id<NSObject,ODNodeRendererFactory>)_factory
  forNamespaceURI:(NSString *)_namespaceURI
{
  [self registerFactory:_factory
        forNamespaceURI:_namespaceURI
        tagName:nil];
}


/* lookup */

- (ODNodeRenderer *)rendererForTextNode:(id)_domNode 
  inContext:(WOContext *)_ctx
{
  static id r = nil;
  if (r == nil) r = [[ODRNodeText alloc] init];
  return r;
}

- (ODNodeRenderer *)rendererForElementNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  ODNodeRenderer *renderer;
  NSString *key;
  unsigned i, count;

  key = [NSString stringWithFormat:@"{%@}%@",
                    [_domNode namespaceURI], [_domNode tagName]];

  if ((renderer = [self->cache objectForKey:key]))
    return renderer;

#if DEBUG && 0
  NSLog(@"1st lookup renderer: %@", key);
#endif
  
  for (i = 0, count = [self->subfactories count]; i < count; i++) {
    _ODNodeRendererFactorySetEntry *entry;
    
    entry = [self->subfactories objectAtIndex:i];

    if ([entry matchesNode:_domNode]) {
      renderer = [[entry nodeRendererFactory]
                         rendererForNode:_domNode
                         inContext:_ctx];
      if (renderer) break;
    }
  }
  
  if (renderer == nil) {
    /* default tag */
    static id r = nil;
    if (r == nil) r = [[ODRGenericTag alloc] init];
    renderer = r;
  }
  
  if (renderer) {
    if (self->cache == nil)
      self->cache = [[NSMutableDictionary alloc] initWithCapacity:64];
    [self->cache setObject:renderer forKey:key];
  }
  
  return renderer;
}

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  ODNodeRenderer *renderer;
  
  switch ([_domNode nodeType]) {
    case DOM_TEXT_NODE:
    case DOM_CDATA_SECTION_NODE:
      renderer = [self rendererForTextNode:_domNode inContext:_ctx];
      break;
      
    case DOM_ELEMENT_NODE:
      renderer = [self rendererForElementNode:_domNode inContext:_ctx];
      break;
      
    default: {
      static id compoundRenderer = nil;

      if (compoundRenderer == nil)
        compoundRenderer = [[ODNodeRenderer alloc] init];
      
      renderer = compoundRenderer;
      break;
    }
  }
  return renderer;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:32];
  
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" factories=#%d", [self->subfactories count]];
  [ms appendFormat:@">"];
  
  return ms;
}

@end /* ODNodeRendererFactorySet */

@implementation _ODNodeRendererFactorySetEntry

- (void)dealloc {
  RELEASE(self->factory);
  RELEASE(self->namespaceURI);
  RELEASE(self->tagName);
  RELEASE(self->qualifier);
  [super dealloc];
}

- (BOOL)matchesNode:(id)_node {
  if (self->namespaceURI) {
    if (![self->namespaceURI isEqualToString:[_node namespaceURI]])
      return NO;
  }
  if (self->tagName) {
    if (![self->tagName isEqualToString:[_node tagName]])
      return NO;
  }
  if (self->qualifier) {
    if (![(id<EOQualifierEvaluation>)self->qualifier evaluateWithObject:_node])
      return NO;
  }
  
  return YES;
}

- (ODNodeRendererFactory *)nodeRendererFactory {
  return self->factory;
}

@end /* _ODNodeRendererFactorySetEntry */
