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

@interface WOThresholdColoredNumber : WODynamicElement
{
  WOAssociation *lowColor;
  WOAssociation *highColor;
  WOAssociation *threshold;
  WOAssociation *value;
  WOAssociation *numberFormat;
}
@end

#import <Foundation/NSNumberFormatter.h>
#include "common.h"

@implementation WOThresholdColoredNumber

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_temp
{
  if ((self = [super initWithName:_name associations:_config template:_temp])) {
    self->lowColor     = WOExtGetProperty(_config, @"lowColor");
    self->highColor    = WOExtGetProperty(_config, @"highColor");
    self->threshold    = WOExtGetProperty(_config, @"threshold");
    self->value        = WOExtGetProperty(_config, @"value");
    self->numberFormat = WOExtGetProperty(_config, @"numberformat");
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->lowColor);
  RELEASE(self->highColor);
  RELEASE(self->threshold);
  RELEASE(self->value);
  RELEASE(self->numberFormat);
  
  [super dealloc];
}


// *** responder ***

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSString    *low;     // lowColor     association
  NSString    *high;    // highColor    association
  NSNumber    *t;       // threshold    association
  NSNumber    *v;       // value        association
  NSString    *nFormat; // numberFormat association
  NSString    *color;
  NSString    *result;

  if ([_ctx isRenderingDisabled]) return;

  comp    = [_ctx component];
  low     = [self->lowColor     stringValueInComponent:comp];
  high    = [self->highColor    stringValueInComponent:comp];
  t       = [self->threshold    valueInComponent:comp];
  v       = [self->value        valueInComponent:comp];
  nFormat = [self->numberFormat stringValueInComponent:comp];

  if (![v isKindOfClass:[NSNumber class]]) {
#if DEBUG
    NSLog(@"WARNING! WOThresholdColoredNumber 'value' is not a NSNumber");
    result = @"[WARNING! WOThresholdColoredNumber:'value' must be a NSNumber]";
#else
    result = @"";
#endif
  }
  else if (nFormat) {
    NSNumberFormatter *formatter;

    formatter = AUTORELEASE([[NSNumberFormatter alloc] init]);
    [formatter setFormat:nFormat];
    result = [formatter stringForObjectValue:v];
  }
  else
    result = [v stringValue];

  color = ([v compare:t] == NSOrderedAscending) ? low : high;

  if (color) {
    [_resp appendContentString:@"<FONT COLOR=\""];
    [_resp appendContentString:color];
    [_resp appendContentString:@"\">"];
  }
  [_resp appendContentString:result];
  if (color)
    [_resp appendContentString:@"</FONT>"];
}

@end /* WOThresholdColoredNumber */
