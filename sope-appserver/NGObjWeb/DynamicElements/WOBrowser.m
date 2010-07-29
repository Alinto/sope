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

@interface WOBrowser : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // inherited: name
  // inherited: value
  // inherited: disabled
@protected
  WOAssociation *list;
  WOAssociation *item;
  WOAssociation *selection;         // => use 'selections'!
  WOAssociation *string;            // WO4 => use 'displayString'!
  WOAssociation *noSelectionString; // WO4
  
  // non-WO:
  WOAssociation *singleSelection; // selection contains an item, not an array
  
  // WO 4.5
  WOAssociation *multiple; // multiple selections allowed
  WOAssociation *size;

  // TODO: WO 4.5: selectedValues, escapeHTML
}

@end /* WOBrowser */

@implementation WOBrowser

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
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->list              = OWGetProperty(_config, @"list");
    self->item              = OWGetProperty(_config, @"item");
    self->singleSelection   = OWGetProperty(_config, @"singleSelection");
    self->multiple          = OWGetProperty(_config, @"multiple");
    self->size              = OWGetProperty(_config, @"size");
    self->noSelectionString = OWGetProperty(_config, @"noSelectionString");
    
    if ((self->string = OWGetProperty(_config, @"displayString")) == nil) {
      if ((self->string = OWGetProperty(_config, @"string")) != nil) {
	[self debugWithFormat:
		@"Note: using deprecated 'string' binding, "
	        @"use 'displayString' instead."];
      }
    }
    else if (OWGetProperty(_config, @"string") != nil) {
      [self debugWithFormat:@"WARNING: 'displayString' AND 'string' bindings "
	      @"are set, use only one! ('string' is deprecated!)"];
    }
    
    if ((self->selection = OWGetProperty(_config, @"selections")) == nil) {
      if ((self->selection = OWGetProperty(_config, @"selection")) != nil) {
	[self debugWithFormat:
		@"Note: using deprecated 'selection' binding, "
	        @"use 'selections' instead."];
      }
    }
    else if (OWGetProperty(_config, @"selection") != nil) {
      [self debugWithFormat:@"WARNING: 'selections' AND 'selection' bindings "
	      @"are set, use only one! ('selection' is deprecated!)"];
    }
    
    // compatiblity
    if (self->noSelectionString == nil)
      self->noSelectionString = OWGetProperty(_config, @"nilString");
    
    if (self->multiple == nil) {
      self->multiple =
        [WOAssociation associationWithValue:[NSNumber numberWithBool:YES]];
      self->multiple = [self->multiple retain];
    }
  }
  return self;
}

- (void)dealloc {
  [self->noSelectionString release];
  [self->singleSelection   release];
  [self->list      release];
  [self->item      release];
  [self->selection release];
  [self->string    release];
  [self->size      release];
  [self->multiple  release];
  [super dealloc];
}

/* handling request */

- (void)_takeSingleFormValue:(id)formValue fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
  NSArray *objects;
  id      object;
      
  sComponent = [_ctx component];
  objects = [self->list valueInComponent:sComponent];
      
  if ([[formValue stringValue] isEqualToString:@"$"])
    object = nil; // nil item selected
  else {
    int idx;
      
    object = nil;
    if ((idx = [formValue intValue]) >= 0) {
      if (idx < (int)[objects count])
        object = [objects objectAtIndex:idx];
      else {
        [sComponent logWithFormat:
                      @"WOBrowser got invalid index '%i' (formvalue='%@') "
                    @"for list with count %i !",
                    idx, formValue, [objects count]];
      }
    }
    else
      [sComponent logWithFormat:@"WOBrowser got invalid index '%i' !", idx];
  }
    
  if ([self->selection isValueSettable]) {
    NSArray *sel;
        
    if ([self->item isValueSettable])
      [self->item setValue:object inComponent:sComponent];

    if (object) {
      sel = [self->singleSelection boolValueInComponent:sComponent]
        ? [object retain]
        : [[NSArray alloc] initWithObjects:object,nil];
    }
    else // nil item selected
      sel = nil;
          
    [self->selection setValue:sel inComponent:sComponent];
    [sel release]; sel = nil;
  }
}

- (void)_takeMultiFormValue:(NSArray *)formValue fromRequest:(WORequest *)_rq
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
  NSEnumerator   *values;
  NSString       *v;
  NSArray        *objects;
  id             object;
  
  values     = [formValue objectEnumerator];
  sComponent = [_ctx component];
  objects    = [self->list valueInComponent:sComponent];
    
  if ([self->selection isValueSettable]) {
    NSMutableArray *sel;
    unsigned objCount;
      
    sel      = [[NSMutableArray alloc] initWithCapacity:[formValue count]];
    objCount = [objects count];
      
    while ((v = [values nextObject])) {
        int idx;

        object = nil;
        if ((idx = [v intValue]) >= 0) {
          if (idx < (int)objCount)
            object = [objects objectAtIndex:idx];
          else {
            [sComponent logWithFormat:
                          @"WOBrowser got invalid index '%i'(formValue='%@' "
                          @"for list with count %i !",
                          idx, objCount, v];
          }
          
          if ([self->item isValueSettable])
            [self->item setValue:object inComponent:sComponent];
        }
        else {
          [sComponent logWithFormat:@"WOBrowser got invalid index '%i' !",
                        idx];
        }
        
        if (object) [sel addObject:object];
    }

    if ([self->singleSelection boolValueInComponent:sComponent]) {
        if ([sel count] > 1) {
          NSLog(@"WARNING(%@): "
                @"using singleSelection with multiple selected values",
                self);
        }
        [self->selection setValue:[sel lastObject] inComponent:sComponent];
    }
    else
      [self->selection setValue:sel inComponent:sComponent];
    [sel release]; sel = nil;
  }
}

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
  id formValue = nil;
  
  sComponent = [_ctx component];
  if ([self->disabled boolValueInComponent:sComponent])
    return;
  
  formValue = [_request formValuesForKey:OWFormElementName(self, _ctx)];
#if 0
  [self logWithFormat:@"value=%@ ..", formValue];
#endif
  
  if ([self->value isValueSettable])
    // TODO: is this correct?
    [self->value setValue:formValue inComponent:sComponent];
  
  if ([formValue count] == 1) {
    [self _takeSingleFormValue:[formValue lastObject] fromRequest:_request
          inContext:_ctx];
  }
  else if (formValue != nil) {
    [self _takeMultiFormValue:formValue fromRequest:_request
          inContext:_ctx];
  }
  else {
    // nothing selected
    if ([self->item isValueSettable])
      [self->item setValue:nil inComponent:sComponent];
    if ([self->selection isValueSettable])
      [self->selection setValue:nil inComponent:sComponent];
  }
}

/* generate response */

- (void)appendOptionsToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent;
  BOOL     isSingle;
  NSString *nilStr;
  NSArray  *array;
  id       selArray;
  int      i, toGo;
    
  sComponent = [_ctx component];

  nilStr   = [self->noSelectionString stringValueInComponent:sComponent];
  isSingle = [self->singleSelection boolValueInComponent:sComponent];
  array    = [self->list            valueInComponent:sComponent];
  selArray = [self->selection       valueInComponent:sComponent];
  toGo     = [array count];

  if (nilStr != nil) {
    WOResponse_AddCString(_response, "<option value=\"$\">");
    WOResponse_AddHtmlString(_response, nilStr);
    WOResponse_AddCString(_response, "</option>");
  }
  
  for (i = 0; i < toGo; i++) {
    NSString *v, *displayV;
    id       object;
    BOOL     isSelected;

    object = [array objectAtIndex:i];

    if ([self->item isValueSettable])
      [self->item setValue:object inComponent:sComponent];

    isSelected = NO;
    if (selArray != nil) {
      isSelected = isSingle 
        ? [selArray isEqual:object] : [selArray containsObject:object];
    }
    
    v = (self->value != nil)
      ? [self->value stringValueInComponent:sComponent]
      : (NSString *)[NSString stringWithFormat:@"%i", i]; // TODO: slow

    displayV = self->string
      ? [self->string stringValueInComponent:sComponent]
      : [object stringValue];
    
    if (displayV == nil) displayV = @"";
    
    WOResponse_AddCString(_response, "<option value=\"");
    WOResponse_AddString(_response, v);
    if (isSelected) {
      WOResponse_AddString(_response, _ctx->wcFlags.allowEmptyAttributes 
			   ? @"\" selected>" : @"\" selected=\"selected\">");
    }
    else {
      WOResponse_AddString(_response, @"\">");
    }
    WOResponse_AddHtmlString(_response, displayV);
    WOResponse_AddCString(_response, "</option>");
  }
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  BOOL     isMultiple;
  unsigned s;
  
  if ([[_ctx request] isFromClientComponent])
    return;

  isMultiple = [self->multiple boolValueInComponent:[_ctx component]];
  s          = [self->size unsignedIntValueInComponent:[_ctx component]];
    
  WOResponse_AddCString(_response, "<select name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                           [_ctx component]]);
  }
  WOResponse_AddCString(_response, "\"");
      
  if (s > 0) {
    WOResponse_AddCString(_response, " size=\"");
    WOResponse_AddUInt(_response, s);
    [_response appendContentCharacter:'"'];
  }

  if ([self->disabled boolValueInComponent:[_ctx component]])
    WOResponse_AddCString(_response, " disabled=\"disabled\"");
      
  if (isMultiple)
    WOResponse_AddCString(_response, " multiple=\"multiple\"");
    
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  WOResponse_AddCString(_response, ">\n");
  
  [self appendOptionsToResponse:_response inContext:_ctx];
  
  WOResponse_AddCString(_response, "</select>");
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:256];
  [str appendString:[super associationDescription]];
  
  if (self->list)      [str appendFormat:@" list=%@",      self->list];
  if (self->item)      [str appendFormat:@" item=%@",      self->item];
  if (self->selection) [str appendFormat:@" selection=%@", self->selection];
  if (self->string)    [str appendFormat:@" string=%@",    self->string];
  if (self->noSelectionString)
    [str appendFormat:@" noselection=%@", self->noSelectionString];
  if (self->singleSelection)
    [str appendFormat:@" singleSelection=%@", self->singleSelection];

  if (self->size)     [str appendFormat:@" size=%@",     self->size];
  if (self->multiple) [str appendFormat:@" multiple=%@", self->multiple];

  return str;
}

@end /* WOBrowser */
