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

@class WOAssociation;

@interface WOPopUpButton : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
@protected
  WOAssociation *list;
  WOAssociation *item;
  WOAssociation *selection;
  WOAssociation *string;            // WO4
  WOAssociation *noSelectionString; // WO4
  WOAssociation *selectedValue;     // WO4.5
  WOAssociation *escapeHTML;        // WO4.5
  WOAssociation *itemGroup;         // SOPE
  WOElement     *template;          // SOPE?
}

@end

@class WOResponse, WOContext;

@interface WOPopUpButton(PrivateMethods)
- (void)appendOptionsToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;
@end

#include "decommon.h"

#ifdef DEBUG
static int profElements  = -1;
static Class NSDateClass = Nil;

@interface WOContext(ComponentStackCount)
- (unsigned)componentStackCount;
@end

#endif

@implementation WOPopUpButton

static NSNumber *yesNum = nil;
static BOOL debugPopUp = NO;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if (yesNum == nil) yesNum = [[NSNumber numberWithBool:YES] retain];
}

- (void)_handleDeprecatedBindings:(NSDictionary *)_config {
  id tmp;
  
  if ((tmp = OWGetProperty(_config, @"singleSelection"))) {
    if ([tmp isValueConstant]) {
      if ([tmp boolValueInComponent:nil]) {
	[self debugWithFormat:
		@"Note: template uses deprecated 'singleSelection' binding!"];
      }
      else {
	  [self errorWithFormat:
            @"'singleSelection' binding is set to NO, which is "
            @"unsupported now!"];
      }
    }
    else {
      [self errorWithFormat:
              @"will ignore deprecated 'singleSelection' binding: %@", tmp];
    }
    [tmp release];
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
#if DEBUG
  if (profElements == -1) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    profElements = [[ud objectForKey:@"WOProfileElements"] boolValue] ? 1 : 0;
  }
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
#endif
  
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->list              = OWGetProperty(_config, @"list");
    self->item              = OWGetProperty(_config, @"item");
    self->selection         = OWGetProperty(_config, @"selection");
    self->string            = OWGetProperty(_config, @"string");
    if (self->string == nil )
        self->string = OWGetProperty(_config, @"displayString");
    
    self->noSelectionString = OWGetProperty(_config, @"noSelectionString");
    self->selectedValue     = OWGetProperty(_config, @"selectedValue");
    self->escapeHTML        = OWGetProperty(_config, @"escapeHTML");
    self->itemGroup         = OWGetProperty(_config, @"itemGroup");

    self->template = [_t retain];
    
    if (self->selection != nil && self->selectedValue != nil)
      [self logWithFormat:
        @"cannot have both 'selection' and 'selectedValue' bindings!"];
    
    /* compatibility */
    
    if (self->noSelectionString == nil)
      self->noSelectionString = OWGetProperty(_config, @"nilString");
    
    if (self->escapeHTML == nil)
      self->escapeHTML = [[WOAssociation associationWithValue:yesNum] retain];

    [self _handleDeprecatedBindings:_config];
  }
  return self;
}

- (void)dealloc {
  [self->noSelectionString release];
  [self->escapeHTML        release];
  [self->list              release];
  [self->item              release];
  [self->selection         release];
  [self->string            release];
  [self->selectedValue     release];
  [self->itemGroup         release];
  [super dealloc];
}

/* handling the request */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *formValue;
  NSArray     *objects;
  id          object;
  
  sComponent = [_ctx component];
  if ([self->disabled boolValueInComponent:[_ctx component]])
    return;
  
  formValue = [_rq formValueForKey:OWFormElementName(self, _ctx)];
  if (debugPopUp) {
    [self logWithFormat:@"%@ / %@: value=%@ ..", OWFormElementName(self, _ctx),
          [_ctx elementID], formValue];
  }
  
  if (formValue == nil) {
    /* nothing changed, or not in submitted form */
    if (debugPopUp) [self logWithFormat:@"found no form value!"];
    return;
  }
      
  objects = [self->list valueInComponent:sComponent];
      
  object = nil;
  if (self->value != nil) {
    /* has a value binding, walk list to find object */
    unsigned i, toGo;
    
    if (debugPopUp) [self logWithFormat:@"scan value: %@", self->value];
    
    for (i = 0, toGo = [objects count]; i < toGo; i++) {
      NSString *cv;
          
      object = [objects objectAtIndex:i];
      
      if ([self->item isValueSettable])
        [self->item setValue:object inComponent:sComponent];
      
      cv = [self->value stringValueInComponent:sComponent];
          
      if ([cv isEqualToString:formValue])
	break;
      
      // important, reset object otherwise the last item will be preselected!
      object = nil;
    }
  }
  else if (![formValue isEqualToString:WONoSelectionString]) {
    /* an index binding */
    int idx;
        
    idx = [formValue intValue];
    if (idx >= (int)[objects count]) {
      [[_ctx page] logWithFormat:@"popup-index %i out of range 0-%i",
		     idx, [objects count] - 1];
      object = nil;
    }
    else 
      object = [objects objectAtIndex:idx];
  }

  if ([self->selectedValue isValueSettable])
      [self->selectedValue setValue:formValue inComponent:sComponent];

  /* process selection */
      
  if ([self->selection isValueSettable]) {
    NSArray *sel;
        
    if (object != nil) {
      sel = [object retain];
    }
    else /* nil item selected */
      sel = nil;
          
    [self->selection setValue:sel inComponent:sComponent];
    [sel release]; sel = nil;
  }
  if ([self->item isValueSettable])
    [self->item setValue:nil inComponent:sComponent]; // Reset 'item'
}

/* generate response */

- (void)appendOptionsToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent = [_ctx component];
  NSString *nilStr  = nil;
  NSArray  *array   = nil;
  id       sel = nil;
  int      i, toGo;
  BOOL     escapesHTML;
  BOOL     byVal;
  id       previousGroup = nil;
#if DEBUG
  NSTimeInterval st = 0.0;
    
  if (profElements)
    st = [[NSDateClass date] timeIntervalSince1970];
#endif
    
  escapesHTML = [self->escapeHTML        boolValueInComponent:sComponent];
  nilStr      = [self->noSelectionString stringValueInComponent:sComponent];
  array       = [self->list              valueInComponent:sComponent];
  if (self->selection == nil){
    if (self->selectedValue != nil){
      byVal = YES;
      sel = [self->selectedValue valueInComponent:sComponent];
    }
    else{
      byVal = NO;
      sel = nil;
    }
  }
  else{
    if (self->selectedValue != nil){
      byVal = YES;
      sel = [self->selectedValue valueInComponent:sComponent];
      NSLog(@"WARNING(%@): "
            @"using both 'selection' and 'selectedValue' bindings!",
            self);
    }
    else{
      byVal = NO;
      sel = [self->selection valueInComponent:sComponent];
    }
  }
  toGo     = [array count];
  
#if DEBUG
  if (profElements) {
    NSTimeInterval diff;
    int j;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > 0.001) {
      for (j = [_ctx componentStackCount]; j >= 0; j--)
        printf("  ");
      printf("PopUpOption[setup] %s: %0.3fs\n",
             [[_ctx elementID] cString], diff);
    }
  }
#endif
  
  if (nilStr != nil) {
    if (self->itemGroup != nil) {
      id  group;
      
      if ([self->item isValueSettable])
        [self->item setValue:nil inComponent:sComponent];
      group = [self->itemGroup stringValueInComponent:sComponent];
      
      if (group != nil) {
        WOResponse_AddCString(_response, "<optgroup label=\"");
        if (escapesHTML) {
          WOResponse_AddHtmlString(_response, group);
	}
        else {
          WOResponse_AddString(_response, group);
	}
        WOResponse_AddCString(_response, "\">");
        previousGroup = [group retain];
      }
    }
    WOResponse_AddCString(_response, "<option value=\"");
    WOResponse_AddString(_response, WONoSelectionString);
    WOResponse_AddCString(_response, "\">");
    WOResponse_AddHtmlString(_response, nilStr);
    WOResponse_AddCString(_response, "</option>");
    // FIXME (stephane) Shouldn't we set the 'selected' if selArray/selValueArray is empty?
  }
  
  for (i = 0; i < toGo; i++) {
    NSString *v         = nil;
    NSString *displayV  = nil;
    id       object;
    BOOL     isSelected;
    id       group;
#if DEBUG
    NSTimeInterval st = 0.0;
    
    if (profElements)
      st = [[NSDateClass date] timeIntervalSince1970];
#endif
    
    object = [array objectAtIndex:i];
    
    if ([self->item isValueSettable])
      [self->item setValue:object inComponent:sComponent];
    
    isSelected = sel ? [sel isEqual:object] : NO;
    v = (self->value != nil)
      ? [self->value stringValueInComponent:sComponent]
      : (NSString *)[NSString stringWithFormat:@"%i", i];

    if (byVal){
        isSelected = sel ? [sel isEqual:v] : NO;
    }
    else
      isSelected = sel ? [sel isEqual:object] : NO;
    
    displayV = self->string
      ? [self->string stringValueInComponent:sComponent]
      : [object stringValue];

    if (displayV == nil) displayV = (escapesHTML ? @"<nil>" : @"&lt;nil&gt;");
    
    group = self->itemGroup != nil
      ? [self->itemGroup stringValueInComponent:sComponent]
      : (NSString *)nil;
    
    if (group != nil) {
      BOOL  groupChanged = NO;
      
      if (previousGroup == nil)
        groupChanged = YES;
      else {
        if (![group isEqualToString:previousGroup]) {
          WOResponse_AddCString(_response, "</optgroup>");
          groupChanged = YES;
        }
      }
      if (groupChanged) {
        WOResponse_AddCString(_response, "<optgroup label=\"");
        if (escapesHTML) {
          WOResponse_AddHtmlString(_response, group);
	}
        else {
          WOResponse_AddString(_response, group);
	}
        WOResponse_AddCString(_response, "\">");
        ASSIGN(previousGroup, group);
      }
    }
    else {
      if (previousGroup != nil) {
        WOResponse_AddCString(_response, "</optgroup>");
        ASSIGN(previousGroup, nil);
      }
    }
    WOResponse_AddCString(_response, "<option value=\"");
    WOResponse_AddHtmlString(_response, v); // WO escapes it, always
    
    if (isSelected) {
      WOResponse_AddString(_response,
			   _ctx->wcFlags.allowEmptyAttributes 
			   ? @"\" selected>" : @"\" selected=\"selected\">");
    }
    else {
      WOResponse_AddString(_response, @"\">");
    }
    
    if (escapesHTML){
      WOResponse_AddHtmlString(_response, displayV);
    }
    else{
      WOResponse_AddString(_response, displayV);
    }
    WOResponse_AddCString(_response, "</option>");
    
#if DEBUG
    if (profElements) {
      NSTimeInterval diff;
      int j;
      diff = [[NSDateClass date] timeIntervalSince1970] - st;
      if (diff > 0.001) {
#if 1
        for (j = [_ctx componentStackCount]; j >= 0; j--)
          printf("  ");
#endif
        printf("PopUpOption[%i] %s: %0.3fs\n", i,
               [[_ctx elementID] cString], diff);
      }
    }
#endif
  }
  if (previousGroup != nil) {
    WOResponse_AddCString(_response, "</optgroup>");
    [previousGroup release];
  }
  if ([self->item isValueSettable])
    [self->item setValue:nil inComponent:sComponent]; // Reset 'item'
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
#if DEBUG
  NSTimeInterval st = 0.0;

  if (profElements)
    st = [[NSDateClass date] timeIntervalSince1970];
#endif
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
  }
  else {
    WOResponse_AddCString(_response, "<select name=\"");
    [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
    WOResponse_AddChar(_response, '"');
    
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    
    if (self->otherTagString != nil) {
      WOResponse_AddChar(_response, ' ');
      WOResponse_AddString(_response,
                           [self->otherTagString stringValueInComponent:
                                [_ctx component]]);
    }
    
    if ([self->disabled boolValueInComponent:[_ctx component]])
      WOResponse_AddCString(_response, " disabled=\"disabled\"");

    WOResponse_AddChar(_response, '>');
    
    [self appendOptionsToResponse:_response inContext:_ctx];
    [self->template appendToResponse:_response inContext:_ctx];

    WOResponse_AddCString(_response, "</select>");
  }
#if DEBUG
  if (profElements) {
    NSTimeInterval diff;
    int i;
    diff = [[NSDateClass date] timeIntervalSince1970] - st;
    if (diff > 0.001) {
#if 1
      for (i = [_ctx componentStackCount]; i >= 0; i--)
        printf("  ");
#endif
      printf("PopUpButton %s: %0.3fs\n",
             [[_ctx elementID] cString], diff);
    }
  }
#endif
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:256];
  [str appendString:[super associationDescription]];

  if (self->list)      [str appendFormat:@" list=%@",      self->list];
  if (self->item)      [str appendFormat:@" item=%@",      self->item];
  if (self->selection) [str appendFormat:@" selection=%@", self->selection];
  if (self->string)    [str appendFormat:@" displayString=%@", self->string];
  if (self->noSelectionString)
    [str appendFormat:@" noselection=%@", self->noSelectionString];
  if (self->escapeHTML)
    [str appendFormat:@" escapeHTML=%@", self->escapeHTML];
  if (self->selectedValue)
    [str appendFormat:@" selectedValue=%@", self->selectedValue];
  if (self->itemGroup)
    [str appendFormat:@" itemGroup=%@", self->itemGroup];
  
  return str;
}

@end /* WOPopUpButton */
