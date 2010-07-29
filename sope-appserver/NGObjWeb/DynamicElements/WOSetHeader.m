/*
  Copyright (C) 2005 SKYRIX Software AG

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
  WOSetHeader / <var:set-header/>

  This element can set/add a header field using -setHeader:forKey:. Usually its
  used with a WOResponse (context.response is the default 'object'), but can be
  used with arbitary objects implementing the same API (eg context.request).
  
  Usage:
    ChangeContentType: WOSetHeader {
      header = "content-type";
      value  = "text/plain";
    }
  
  Bindings:
    header|key|name   - name of header (should be lowercase for WOResponse)
    value             - value to apply
    addToExisting     - use -appendHeader:forKey: or -setHeader:forKey:?
    object            - object to manipulate (defaults to [context response])
*/

@interface WOSetHeader : WODynamicElement // TODO: should be WOElement?
{
  WOAssociation *object;
  WOAssociation *header;
  WOAssociation *value;
  WOAssociation *addToExisting;
}

@end

#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOMessage.h>
#include <NGObjWeb/WOContext.h>
#include "common.h"

@implementation WOSetHeader

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->header        = OWGetProperty(_config, @"header");
    self->value         = OWGetProperty(_config, @"value");
    self->addToExisting = OWGetProperty(_config, @"addToExisting");
    self->object        = OWGetProperty(_config, @"object");
    
    if (self->header == nil) self->header = OWGetProperty(_config, @"key");
    if (self->header == nil) self->header = OWGetProperty(_config, @"name");
  }
  return self;
}

- (void)dealloc {
  [self->object        release];
  [self->header        release];
  [self->value         release];
  [self->addToExisting release];
  [super dealloc];
}

/* generating response */

- (id)objectForKey:(NSString *)_key inContext:(WOContext *)_ctx {
  if (![_key isNotEmpty])
    return nil;

  if ([_key isEqualToString:@"response"])
    return [_ctx response];
  if ([_key isEqualToString:@"request"])
    return [_ctx request];
  
  [self errorWithFormat:@"Unknown object key: '%@'", _key];
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOMessage *lObject;
  NSString *k, *v;
  BOOL     doAdd;

  doAdd = (self->addToExisting != nil)
    ? [self->addToExisting boolValueInContext:_ctx]
    : NO;

  k = [self->header stringValueInContext:_ctx];
  v = [self->value  stringValueInContext:_ctx];
  
  /* determine object to manipulate */
  
  lObject = (self->object != nil)
    ? [self->object valueInContext:_ctx]
    : (id)[_ctx response];
  if ([lObject isKindOfClass:[NSString class]])
    lObject = [self objectForKey:(NSString *)lObject inContext:_ctx];
  
  /* apply */
  
  if (doAdd) {
    if ([v isNotNull])
      [lObject appendHeader:v forKey:k];
  }
  else
    [lObject setHeader:([v isNotNull] ? v : (NSString *)nil) forKey:k];
}

@end /* WOSetHeader */
