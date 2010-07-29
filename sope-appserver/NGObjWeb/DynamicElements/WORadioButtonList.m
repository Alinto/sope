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

#include "WOInput.h"

@interface WORadioButtonList : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
@protected
  WOAssociation *list;
  WOAssociation *item;
  WOAssociation *index;
  WOAssociation *selection;
  WOAssociation *prefix;
  WOAssociation *suffix;
}

@end /* WORadioButtonList */

#include "decommon.h"

// TODO: add support for template? (does WO provide this?)

@implementation WORadioButtonList

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c 
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->list      = OWGetProperty(_config, @"list");
    self->item      = OWGetProperty(_config, @"item");
    self->index     = OWGetProperty(_config, @"index");
    self->selection = OWGetProperty(_config, @"selection");
    self->prefix    = OWGetProperty(_config, @"prefix");
    self->suffix    = OWGetProperty(_config, @"suffix");
  }
  return self;
}

- (void)dealloc {
  [self->list      release];
  [self->item      release];
  [self->index     release];
  [self->selection release];
  [self->prefix    release];
  [self->suffix    release];
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *sComponent = [_ctx component];
  unsigned idx;
  NSArray  *array;
  id       formValue;
  
  formValue = [_rq formValueForKey:OWFormElementName(self, _ctx)];
  if (formValue == nil)
    return;
  
  idx   = [formValue unsignedIntValue];
  array = [self->list valueInComponent:sComponent];
  
  /* setup item/index */
  
  if ([self->index isValueSettable])
    [self->index setUnsignedIntValue:idx inComponent:sComponent];

  if ([self->item isValueSettable])
    [self->item setValue:[array objectAtIndex:idx] inComponent:sComponent];
  
  /* now check whether the item is disabled/allowed as the selection */

  if ([self->disabled boolValueInComponent:sComponent])
    return;
  
  /* set selection if possible */
  
  if ([self->selection isValueSettable]) {
    [self->selection setValue:[array objectAtIndex:idx]
	             inComponent:sComponent];
  }
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return nil;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSArray     *array;
  unsigned    goCount;
  unsigned    cnt;
  NSString    *n;
  id          sel;
  BOOL        canSetIndex, canSetItem;
  
  if ([_ctx isRenderingDisabled]) return;

  sComponent = [_ctx component];
  array      = [self->list valueInComponent:sComponent];
  goCount    = [array count];

  if (goCount <= 0)
    return;

  n   = OWFormElementName(self, _ctx);
  sel = [self->selection valueInComponent:sComponent];

  canSetIndex = [self->index isValueSettable];
  canSetItem  = [self->item  isValueSettable];
  
  for (cnt = 0; cnt < goCount; cnt++) {
    id object;
    
    object = [array objectAtIndex:cnt];

    if (canSetIndex)
      [self->index setUnsignedIntValue:cnt inComponent:sComponent];
    
    if (canSetItem)
      [self->item setValue:object inComponent:sComponent];

    if (self->prefix != nil) {
      WOResponse_AddString(_response,
			   [self->prefix stringValueInComponent:sComponent]);
    }

    /* add radio button */
    {
      WOResponse_AddCString(_response, "<input type=\"radio\" name=\"");
      [_response appendContentHTMLAttributeValue:n];
      WOResponse_AddCString(_response, "\" value=\"");
      WOResponse_AddInt(_response, cnt);
      WOResponse_AddCString(_response, "\"");
      
      if (sel == object || [sel isEqual:object]) {
	WOResponse_AddCString(_response, 
			      (_ctx->wcFlags.allowEmptyAttributes 
			       ? " checked" : " checked=\"checked\""));
      }
      
      if ([self->disabled boolValueInComponent:sComponent]) {
	WOResponse_AddCString(_response, 
			      (_ctx->wcFlags.allowEmptyAttributes
			       ? " disabled" : " disabled=\"disabled\""));
      }
      
      [self appendExtraAttributesToResponse:_response inContext:_ctx];
      if (self->otherTagString != nil) {
	NSString *s;
	
	s = [self->otherTagString stringValueInComponent:sComponent];
        WOResponse_AddChar(_response, ' ');
	WOResponse_AddString(_response, s);
      }
      WOResponse_AddEmptyCloseParens(_response, _ctx);
  
      // the value in a radio list is the string besides the button
      if (self->value != nil) {
	NSString *s;
	
	s = [self->value stringValueInComponent:sComponent];
	WOResponse_AddHtmlString(_response, s);
      }
    }
        
    if (self->suffix != nil) {
      WOResponse_AddString(_response,
			   [self->suffix stringValueInComponent:sComponent]);
    }
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:128];
  [str appendString:[super associationDescription]];
  if (self->list)      [str appendFormat:@" list=%@",      self->list];
  if (self->item)      [str appendFormat:@" item=%@",      self->item];
  if (self->index)     [str appendFormat:@" index=%@",     self->index];
  if (self->prefix)    [str appendFormat:@" prefix=%@",    self->prefix];
  if (self->suffix)    [str appendFormat:@" suffix=%@",    self->suffix];
  if (self->selection) [str appendFormat:@" selection=%@", self->selection];

  return str;
}

@end /* WORadioButtonList */
