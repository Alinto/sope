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

#include <NGObjWeb/NGObjWeb.h>

@interface WODictionaryRepetition : WODynamicElement
{
@protected
  WOAssociation *dictionary;
  WOAssociation *key;
  WOAssociation *item;

  WOElement *template;
}
@end

#include "common.h"

/* TODO: the implementation does not work with keys that contain a dot! */

@implementation WODictionaryRepetition

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_temp
{
  if ((self = [super initWithName:_name associations:_config template:_temp])) {
    self->dictionary = WOExtGetProperty(_config, @"dictionary");
    self->key        = WOExtGetProperty(_config, @"key");
    self->item       = WOExtGetProperty(_config, @"item");

    self->template = [_temp retain];
  }
  return self;
}

- (void)dealloc {
  [self->dictionary release];
  [self->key        release];
  [self->item       release];
  [self->template   release];
  [super dealloc];
}

- (NSString *)unescapeKey:(NSString *)_key {
  return _key;
}
- (NSString *)escapeKey:(NSString *)_key {
  if ([_key rangeOfString:@"."].length == 0)
    return _key;
#if 0
  NSLog(@"WARNING(%s): key '%@' can't be processed by "
        @"WODictionaryRepetition !!",
        __PRETTY_FUNCTION__, _key);
#endif
  return _key;
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent  *comp;
  NSDictionary *dict;
  NSEnumerator *keyEnum;
  NSString     *k;
  BOOL         isMutable;
  id           obj;
  
  comp    = [_ctx component];
  dict    = [self->dictionary valueInComponent:comp];
  keyEnum = [dict keyEnumerator];

  isMutable = [dict isKindOfClass:[NSMutableDictionary class]];

#if 0
  if (!isMutable) {
    NSLog(@"WARNING: WODictionaryRepetition: 'dictionary' is immutable."
          @" Cannot change values.");
  }
#endif
  
  while ((k = [keyEnum nextObject])) {
    
    if ([self->key isValueSettable])
      [self->key setValue:k inComponent:comp];
    
    [_ctx appendElementIDComponent:[self escapeKey:k]];
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx deleteLastElementIDComponent];

    if (isMutable) {
      obj = [self->item valueInComponent:comp];
      if (obj) {
        [(NSMutableDictionary *)dict setObject:obj forKey:k];
      }
      else
        NSLog(@"WARNING: WODictionaryRepetition: nil object forKey: '%@'", k);
    }
  }
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent  *comp;
  NSDictionary *dict;
  NSString     *k;
  id           obj;
  id           result = nil;

  comp = [_ctx component];
  dict = [self->dictionary valueInComponent:comp];
  k    = [self unescapeKey:[_ctx currentElementID]];
  
  if (k) {
    if ((obj = [dict objectForKey:k])) {
      if ([self->item isValueSettable])
        [self->item setValue:obj inComponent:comp];
      if ([self->key isValueSettable])
        [self->key setStringValue:k inComponent:comp];

      [_ctx consumeElementID]; // consume k

      [_ctx appendElementIDComponent:k];
      result = [self->template invokeActionForRequest:_req inContext:_ctx];
      [_ctx deleteLastElementIDComponent];
    }
    else 
      NSLog(@"WARNING: WODictionaryRepetition nil object for key:'%@'", k);
  }
  return result;
}

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent  *comp;
  NSDictionary *dict;
  NSEnumerator *keyEnum;
  NSString     *k;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_resp inContext:_ctx];
    return;
  }
  
  comp = [_ctx component];
  dict = [self->dictionary valueInComponent:comp];
  
  keyEnum = [dict keyEnumerator];
  
  while ((k = [keyEnum nextObject])) {
    if ([self->item isValueSettable])
      [self->item setValue:[dict objectForKey:k] inComponent:comp];
    if ([self->key isValueSettable])
      [self->key setStringValue:k inComponent:comp];
    
    [_ctx appendElementIDComponent:[self escapeKey:k]];
    [self->template appendToResponse:_resp inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
}
  
@end /* WODictionaryRepetition */
