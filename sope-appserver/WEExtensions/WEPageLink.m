/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGObjWeb/WODynamicElement.h>

/*
  WEPageLink
  
  This element is pretty similiar to WOHyperlink with the "pageName" binding,
  but in addition allows for parameters being passed to the page.

  WEPageLink associations:
    
    pageName
    sync     (either array of names or a string with names seperated by ',')
*/

@class WOAssociation, WOElement;
@class NSDictionary;

@interface WEPageLink : WODynamicElement
{
  // WODynamicElement: otherTagString
@protected
  WOAssociation *pageName;
  WOAssociation *syncBindings;
  WOElement     *template;
  unsigned      keyCount;
  NSArray       *keys;
  NSArray       *assocs;
}

@end

#include "common.h"

@implementation WEPageLink

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    NSMutableArray *mkeys, *massocs;
    NSEnumerator *e;
    NSString *k;
    
    self->pageName     = WOExtGetProperty(_config, @"pageName");
    self->syncBindings = WOExtGetProperty(_config, @"sync");
    self->template = [_t retain];
    
    self->keyCount = [_config count];
    mkeys   = [[NSMutableArray alloc] initWithCapacity:self->keyCount];
    massocs = [[NSMutableArray alloc] initWithCapacity:self->keyCount];
    
    e = [_config keyEnumerator];
    while ((k = [e nextObject])) {
      [mkeys addObject:k];
      [massocs addObject:[_config objectForKey:k]];
    }
    self->keys   = [mkeys   copy]; [mkeys   release];
    self->assocs = [massocs copy]; [massocs release];
    
    [(NSMutableDictionary *)_config removeAllObjects];
  }
  return self;
}

- (void)dealloc {
  [self->syncBindings release];
  [self->template release];
  [self->pageName release];
  [self->keys     release];
  [self->assocs   release];
  [super dealloc];
}

/* handling requests */

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *page, *sComponent;
  NSString    *name;
  unsigned    i;
  id sync;
  
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]])
    /* link is not the active element */
    return [self->template invokeActionForRequest:_rq inContext:_ctx];

  /* link is the active element */
  
  sComponent = [_ctx component];
  name = [self->pageName stringValueInComponent:sComponent];
  page = [[_ctx application] pageWithName:name inContext:_ctx];
  
  if (page == nil) {
    [self logWithFormat:@"did not find page with name '%@'.", name];
    return nil;
  }
  
  /* apply sync bindings */
  
  if ((sync = [self->syncBindings valueInComponent:sComponent])) {
    unsigned count;
    
    if (![sync isKindOfClass:[NSArray class]])
      sync = [[sync stringValue] componentsSeparatedByString:@","];
    
    // Note: we cannot use keypathes in a useful way here because we reuse
    //       the key for assignment
    for (i = 0, count = [sync count]; i < count; i++) {
      NSString *key;
      id value;
      
      key   = [sync objectAtIndex:i];
      value = [sComponent valueForKey:key];
      [page takeValue:value forKey:key];
    }
  }
  
  /* apply bindings */
  
  for (i = 0; i < self->keyCount; i++) {
    id value;
    
    value = [[self->assocs objectAtIndex:i] valueInComponent:sComponent];
    [page takeValue:value forKey:[self->keys objectAtIndex:i]];
  }
  
  return page;
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *href;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  href = [_ctx componentActionURL];
  [_response appendContentCString:(unsigned char *)"<a href=\""];
  [_response appendContentString:href];
  [_response appendContentCharacter:'"'];
  
  if (self->otherTagString) {
    [_response appendContentCharacter:' '];
    [_response appendContentString:
      [self->otherTagString stringValueInComponent:[_ctx component]]];
  }
  [_response appendContentCharacter:'>'];
  
  [self->template appendToResponse:_response inContext:_ctx];
  [_response appendContentCString:(unsigned char *)"</a>"];
}

@end /* WEPageLink */
