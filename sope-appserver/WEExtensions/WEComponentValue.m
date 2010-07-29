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

@interface WEComponentValue : WODynamicElement
{
  WOAssociation *value;
  WOAssociation *boolValue;
  WOAssociation *stringValue;
  WOAssociation *intValue;
  WOAssociation *unsignedIntValue;
  WOAssociation *key;
}
@end

#include "common.h"

@implementation WEComponentValue

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    int cnt = 0;
    
    self->value            = WOExtGetProperty(_config, @"value");
    self->boolValue        = WOExtGetProperty(_config, @"boolValue");
    self->stringValue      = WOExtGetProperty(_config, @"stringValue");
    self->intValue         = WOExtGetProperty(_config, @"intValue");
    self->unsignedIntValue = WOExtGetProperty(_config, @"unsignedIntValue");
    self->key              = WOExtGetProperty(_config, @"key");

    if (self->value)            cnt++;
    if (self->boolValue)        cnt++;
    if (self->stringValue)      cnt++;
    if (self->intValue)         cnt++;
    if (self->unsignedIntValue) cnt++;

    if (cnt == 0)
      NSLog(@"Warning: WEComponentValue neither 'value', 'boolValue',"
            @"  'stringValue', 'intValue' nor 'unsignedIntValue' is set");
    if (cnt > 0)
      NSLog(@"Warning: WEComponentValue more than one '*Value' is set");
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->value);
  RELEASE(self->boolValue);
  RELEASE(self->stringValue);
  RELEASE(self->intValue);
  RELEASE(self->unsignedIntValue);
  RELEASE(self->key);
  [super dealloc];
}
#endif
  
- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSString    *k;
  id          v;
  SEL         sel;

  comp = [_ctx component];
  k    = [self->key stringValueInComponent:comp];

  if (k == nil) return;

  sel = NSSelectorFromString([k stringByAppendingString:@":"]);
  sel = ([comp respondsToSelector:sel]) ? sel : NULL;

#define _assign(_v_, _k_)                                            \
                   {                                                 \
                     if (sel != NULL)                                \
                       [comp performSelector:sel withObject:_v_];    \
                     else                                            \
                       [comp takeValue:_v_ forKey:_k_];              \
                   }                                                 \

  if ((v = [self->value valueInComponent:comp])) {
    _assign(v, k);
  }
  else if (self->boolValue) {
    v = [NSNumber numberWithBool:[self->boolValue boolValueInComponent:comp]];
    _assign(v, k);
  }
  else if ((v = [self->stringValue stringValueInComponent:comp])) {
    _assign(v, k);
  }
  else if (self->intValue) {
    v = [NSNumber numberWithInt:[self->intValue intValueInComponent:comp]];
    _assign(v, k);
  }
  else if (self->unsignedIntValue) {
    v = [NSNumber numberWithUnsignedInt:
                  [self->unsignedIntValue unsignedIntValueInComponent:comp]];
    _assign(v, k);
  }
    
#undef _assignValue
}

@end /* WEComponentValue */
