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
#include "decommon.h"

@interface WOCheckBoxList : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // inherited: name
  // inherited: value
  // inherited: disabled
@protected
  WOAssociation *list;
  WOAssociation *item;
  WOAssociation *index;
  WOAssociation *selections;
  WOAssociation *prefix;
  WOAssociation *suffix;
}

@end /* WOCheckBoxList */

@implementation WOCheckBoxList

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->list       = OWGetProperty(_config, @"list");
    self->item       = OWGetProperty(_config, @"item");
    self->index      = OWGetProperty(_config, @"index");
    self->selections = OWGetProperty(_config, @"selections");
    self->prefix     = OWGetProperty(_config, @"prefix");
    self->suffix     = OWGetProperty(_config, @"suffix");
  }
  return self;
}

- (void)dealloc {
  [self->list       release];
  [self->item       release];
  [self->index      release];
  [self->selections release];
  [self->prefix     release];
  [self->suffix     release];
  [super dealloc];
}

/* OWResponder */

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  /*
    Checkboxes are special in their form-value handling. If the form is
    submitted and the checkbox is checked, a 'YES' value is transferred in the
    request. If the checkbox is not-checked, no value is transferred at all !

    Remember, the 'value' of a checkbox list is _not_ the form value but the
    string besides the checkbox.
  */
    // could be optimized to use a single NAME with multiple values ..
    WOComponent *sComponent = [_ctx component];
    NSArray     *array      = [self->list valueInComponent:sComponent];
    NSArray     *selArray   = nil;
    unsigned    goCount     = [array count];

  if ([self->disabled boolValueInComponent:[_ctx component]])
    return;
  
  if (goCount > 0) {
    NSMutableArray *newSelection = nil;
    unsigned cnt;

    if (self->selections)
      newSelection = [[NSMutableArray alloc] initWithCapacity:goCount];

    [_ctx appendZeroElementIDComponent];
    
    for (cnt = 0; cnt < goCount; cnt++) {
      id formValue = nil;
      id object    = [array objectAtIndex:cnt];

      if (self->index)
	[self->index setUnsignedIntValue:cnt inComponent:sComponent];

      if (self->item)
	[self->item setValue:object inComponent:sComponent];

      formValue = [_request formValueForKey:OWFormElementName(self, _ctx)];
      if ([formValue isEqualToString:[self stringForInt:cnt]]) {
	if ((object != nil) && (self->selections != nil))
	  [newSelection addObject:object];
      }
      [_ctx incrementLastElementIDComponent];
    }
    
    [_ctx deleteLastElementIDComponent]; // list index

    if (self->selections) {
      selArray = [newSelection copy];
      [newSelection release];
    }
  }
  else if (self->selections)
    selArray = [[NSArray alloc] init];

  if ([self->selections isValueSettable])
    [self->selections setValue:selArray inComponent:sComponent];

  [selArray release];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  return nil;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSArray     *array;
  unsigned    goCount;
  NSArray     *selArray;
  unsigned    cnt;
  BOOL        canSetIndex, canSetItem;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  sComponent = [_ctx component];
  array      = [self->list valueInComponent:sComponent];
  goCount    = [array count];
  
  if (goCount == 0)
    return;

  selArray = [self->selections valueInComponent:sComponent];
  
  [_ctx appendZeroElementIDComponent];

  canSetIndex = [self->index isValueSettable];
  canSetItem  = [self->item  isValueSettable];
  
  for (cnt = 0; cnt < goCount; cnt++) {
    NSString *pLabel, *sLabel;
    id object;
    
    object = [array objectAtIndex:cnt];
    if (canSetIndex)
      [self->index setUnsignedIntValue:cnt inComponent:sComponent];
    
    if (canSetItem)
      [self->item setValue:object inComponent:sComponent];

    pLabel = [self->prefix stringValueInComponent:sComponent];
    sLabel = [self->suffix stringValueInComponent:sComponent];
    if (![pLabel isNotEmpty]) pLabel = nil; /* remove null/empty strings */
    if (![sLabel isNotEmpty]) sLabel = nil; /* remove null/empty strings */

    if (pLabel != nil || sLabel != nil)
      WOResponse_AddCString(_response, "<label>");

    if (pLabel != nil)
      WOResponse_AddString(_response, pLabel);
    
    /* add checkbox */
    {
      NSString *n;
  
      n = self->name != nil
	? [self->name stringValueInComponent:sComponent]
	: OWFormElementName(self, _ctx);
      
      WOResponse_AddCString(_response, "<input type=\"checkbox\" name=\"");
      [_response appendContentHTMLAttributeValue:n];
      WOResponse_AddCString(_response, "\" value=\"");
      WOResponse_AddInt(_response, cnt);
      WOResponse_AddCString(_response, "\"");
      
      if ([self->disabled boolValueInComponent:sComponent]) {
	WOResponse_AddCString(_response, 
			      (_ctx->wcFlags.allowEmptyAttributes
			       ? " disabled" : " disabled=\"disabled\""));
      }
      
      if ([selArray containsObject:object]) {
	WOResponse_AddCString(_response, 
			      (_ctx->wcFlags.allowEmptyAttributes 
			       ? " checked" : " checked=\"checked\""));
      }
      
      [self appendExtraAttributesToResponse:_response inContext:_ctx];
          
      if (self->otherTagString != nil) {
	n = [self->otherTagString stringValueInComponent:sComponent];
	WOResponse_AddChar(_response, ' ');
	WOResponse_AddString(_response, n);
      }
      WOResponse_AddEmptyCloseParens(_response, _ctx);
      
      // the value in a checkbox list is the string besides the checkbox
      if (self->value != nil) {
	n = [self->value stringValueInComponent:sComponent];
	WOResponse_AddHtmlString(_response, n);
      }
    }

    if (sLabel != nil)
      WOResponse_AddString(_response, sLabel);
    if (pLabel != nil || sLabel != nil)
      WOResponse_AddCString(_response, "</label>");
    
    [_ctx incrementLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent]; // list index
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:256];
  [str appendString:[super associationDescription]];
  if (self->list)       [str appendFormat:@" list=%@",       self->list];
  if (self->item)       [str appendFormat:@" item=%@",       self->item];
  if (self->index)      [str appendFormat:@" index=%@",      self->index];
  if (self->prefix)     [str appendFormat:@" prefix=%@",     self->prefix];
  if (self->suffix)     [str appendFormat:@" suffix=%@",     self->suffix];
  if (self->selections) [str appendFormat:@" selections=%@", self->selections];

  return str;
}

@end /* WOCheckBoxList */
