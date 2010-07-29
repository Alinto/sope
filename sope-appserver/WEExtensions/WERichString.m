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

@interface WERichString : WODynamicElement
{
  WOAssociation *isBold;
  WOAssociation *isItalic;
  WOAssociation *isUnderlined;
  WOAssociation *isSmall;
  WOAssociation *color;
  WOAssociation *face;
  WOAssociation *size;
  WOAssociation *insertBR;

  WOAssociation *condition;
  WOAssociation *negate;

  WOAssociation *formatter;
  
  WOAssociation *value;
  
  WOElement     *template;
}

@end

#include <NGObjWeb/NGObjWeb.h>
#include "common.h"

@implementation WERichString

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->value        = OWGetProperty(_config, @"value");
    
    self->isBold       = OWGetProperty(_config, @"isBold");
    self->isItalic     = OWGetProperty(_config, @"isItalic");
    self->isUnderlined = OWGetProperty(_config, @"isUnderlined");
    self->isSmall      = OWGetProperty(_config, @"isSmall");
    self->color        = OWGetProperty(_config, @"color");
    self->face         = OWGetProperty(_config, @"face");
    self->size         = OWGetProperty(_config, @"size");
    self->insertBR     = OWGetProperty(_config, @"insertBR");

    self->condition    = OWGetProperty(_config, @"condition");
    self->negate       = OWGetProperty(_config, @"negate");

    self->formatter    = OWGetProperty(_config, @"formatter");

    ASSIGN(self->template, _t);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->value);
  RELEASE(self->isBold);
  RELEASE(self->isItalic);
  RELEASE(self->isUnderlined);
  RELEASE(self->isSmall);
  RELEASE(self->color);
  RELEASE(self->face);
  RELEASE(self->size);
  RELEASE(self->insertBR);
  RELEASE(self->formatter);

  RELEASE(self->condition);
  RELEASE(self->negate);

  RELEASE(self->template);
  
  [super dealloc];
}

static inline BOOL _doShow(WERichString *self, WOContext *_ctx) {
  BOOL doShow   = YES;
  BOOL doNegate = NO;

  if (self->condition != nil) {
    doShow   = [self->condition boolValueInComponent:[_ctx component]];
    doNegate = [self->negate boolValueInComponent:[_ctx component]];
  }
  
  return (doNegate) ? !doShow : doShow;
}

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if (_doShow(self, _ctx)) {
    [_ctx appendElementIDComponent:@"1"];
    [self->template takeValuesFromRequest:_request inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  NSString *state;

  state = [[_ctx currentElementID] stringValue];
  
  if (state) {
    [_ctx consumeElementID]; // consume state-id (on or off)

    if ([state isEqualToString:@"1"]) {
      id result;
      
      [_ctx appendElementIDComponent:state];
      result = [self->template invokeActionForRequest:_request inContext:_ctx];
      [_ctx deleteLastElementIDComponent];

      return result;
    }
  }
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *comp      = nil;
  BOOL     doBold        = NO;
  BOOL     doItalic      = NO;
  BOOL     doUnderlined  = NO;
  BOOL     doSmall       = NO;
  NSString *color_       = nil;
  NSString *face_        = nil;
  NSString *size_        = nil;
  NSFormatter *fmt       = nil;
  id       v             = nil;

  
  if ([_ctx isRenderingDisabled]) {
    if (_doShow(self, _ctx)) {
      [_ctx appendElementIDComponent:@"1"];
      [self->template appendToResponse:_response inContext:_ctx];
      [_ctx deleteLastElementIDComponent];
    }
    return;
  }
  
  if (!_doShow(self, _ctx)) return;
  
  comp = [_ctx component];
  
  doBold       = [self->isBold       boolValueInComponent:comp];
  doItalic     = [self->isItalic     boolValueInComponent:comp];
  doUnderlined = [self->isUnderlined boolValueInComponent:comp];
  doSmall      = [self->isSmall      boolValueInComponent:comp];
  face_        = [self->face       stringValueInComponent:comp];
  color_       = [self->color      stringValueInComponent:comp];
  size_        = [self->size       stringValueInComponent:comp];
  v            = [self->value            valueInComponent:comp];
  fmt          = [self->formatter        valueInComponent:comp];

  if (doSmall)
    [_response appendContentString:@"<small>"];
  if (doBold)
    [_response appendContentString:@"<b>"];
  if (doItalic)
    [_response appendContentString:@"<i>"];
  if (doUnderlined)
    [_response appendContentString:@"<u>"];

  [_response appendContentString:@"<font"];
  if (color_ != nil) {
    [_response appendContentString:@" color='"];
    [_response appendContentHTMLString:color_];
    [_response appendContentCharacter:'\''];
  }
  if (face_ != nil) {
    [_response appendContentString:@" face='"];
    [_response appendContentHTMLString:face_];
    [_response appendContentCharacter:'\''];
  }
  if (size_ != nil) {
    [_response appendContentString:@" size='"];
    [_response appendContentHTMLString:size_];
    [_response appendContentCharacter:'\''];
  }
  [_response appendContentCharacter:'>'];

  [_ctx appendElementIDComponent:@"1"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];

  v = (fmt)
    ? [fmt stringForObjectValue:v]
    : [v stringValue];

  if (v && [self->insertBR boolValueInComponent:comp]) {
    NSArray *lines;
    unsigned i, count;
      
    lines = [v componentsSeparatedByString:@"\n"];
    count = [lines count];
    for (i = 0; i < count; i++) {
      NSString *line = [lines objectAtIndex:i];

      if (i != 0) {
	[_response appendContentString:
		     (_ctx->wcFlags.xmlStyleEmptyElements)?@"<br />":@"<br>"];
      }

      [_response appendContentHTMLString:line];
    }
  }
  else
    [_response appendContentHTMLString:v];

  [_response appendContentString:@"</font>"];
  if (doUnderlined)
    [_response appendContentString:@"</u>"];
  if (doItalic)
    [_response appendContentString:@"</i>"];
  if (doBold)
    [_response appendContentString:@"</b>"];
  if (doSmall)
    [_response appendContentString:@"</small>"];

}
@end
