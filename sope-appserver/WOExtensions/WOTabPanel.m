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

@interface WOTabPanel : WODynamicElement
{
  WOAssociation *tabs;
  WOAssociation *selectedTab;
  WOAssociation *tabNameKey;
  WOAssociation *nonSelectedBgColor;
  WOAssociation *bgcolor;
  WOAssociation *textColor;
  WOAssociation *submitActionName;
  
  WOElement *template;
}
@end

#include "common.h"

@interface WOContext(NGPrivates)
- (void)addActiveFormElement:(WOElement *)_element;
@end

@implementation WOTabPanel

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->tabs               = WOExtGetProperty(_config, @"tabs");
    self->selectedTab        = WOExtGetProperty(_config, @"selectedTab");
    self->tabNameKey         = WOExtGetProperty(_config, @"tabNameKey");
    
    self->nonSelectedBgColor = 
      WOExtGetProperty(_config, @"nonSelectedBgColor");
    self->bgcolor            = WOExtGetProperty(_config, @"bgcolor");
    self->textColor          = WOExtGetProperty(_config, @"textColor");
    
    self->submitActionName   = WOExtGetProperty(_config, @"submitActionName");

    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->submitActionName release];
  [self->textColor   release];
  [self->bgcolor     release];
  [self->nonSelectedBgColor release];
  [self->tabNameKey  release];
  [self->selectedTab release];
  [self->tabs        release];
  [self->template    release];
  [super dealloc];
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  /* check whether a (form) tab was clicked */
  [_ctx appendElementIDComponent:@"tab"];
  {
    WOComponent *sComponent;
    NSArray     *ttabs;
    unsigned    i;
    
    sComponent = [_ctx component];
    ttabs      = [self->tabs valueInComponent:sComponent];
    
    [_ctx appendZeroElementIDComponent];
    
    for (i = 0; i < [ttabs count]; i++) {
      if ([_req formValueForKey:[_ctx elementID]]) {
        /* found active tab */
        [self->selectedTab setValue:[ttabs objectAtIndex:i]
                           inComponent:sComponent];
        [_ctx addActiveFormElement:self];
        break;
      }
      [_ctx incrementLastElementIDComponent];
    }
    
    [_ctx deleteLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent];

  /* let content take values */
  [_ctx appendElementIDComponent:@"content"];
  [self->template takeValuesFromRequest:_req inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  id       result;
  NSString *section;

  section = [_ctx currentElementID];
  if ([section isEqualToString:@"tab"]) {
    WOComponent *sComponent;
    NSArray *ttabs;
    int idx;
    
    [_ctx consumeElementID]; // consume 'tab'
    
    sComponent = [_ctx component];
    ttabs = [self->tabs valueInComponent:sComponent];

    idx = [[_ctx currentElementID] intValue];
    [_ctx consumeElementID]; // consume index

    if (idx >= (int)[ttabs count]) {
      /* index out of range */
      idx = 0;
    }
    
    [self->selectedTab setValue:[ttabs objectAtIndex:idx]
                       inComponent:sComponent];
    
    result = [_ctx page];
  }
  else if ([section isEqualToString:@"content"]) { 
    [_ctx consumeElementID]; // consume 'content'
    
    [_ctx appendElementIDComponent:@"content"];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  else {
    NSLog(@"%s: missing section id !", __PRETTY_FUNCTION__);
    result = [_ctx page];
  }
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSArray     *ttabs;
  BOOL        isInForm;
  unsigned    i, selIdx;
  NSString    *selColor, *unselColor, *s;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  sComponent = [_ctx component];
  ttabs = [self->tabs valueInComponent:sComponent];

  selColor = self->bgcolor
    ? [self->bgcolor stringValueInComponent:sComponent]
    : (NSString *)@"#CCCCCC";
  
  unselColor = self->nonSelectedBgColor
    ? [self->nonSelectedBgColor stringValueInComponent:sComponent]
    : (NSString *)@"#AAAAAA";
  
  if ([ttabs count] < 1) {
    /* no tabs configured .. */
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [_response appendContentString:@"<table border='0'>"];
  [_response appendContentString:@"<tr>"];

  isInForm = [_ctx isInForm];
  
  /* cannot use -indexOfObjectIdenticalTo:, since this doesn't work
     with language bridges (base types crossing a bridge aren't
     enforced to be identical ... */
  selIdx = [ttabs indexOfObject:
		    [self->selectedTab valueInComponent:sComponent]];
  if (selIdx == NSNotFound)
    selIdx = 0;
  
  [_ctx appendElementIDComponent:@"tab"];
  [_ctx appendZeroElementIDComponent];
  
  for (i = 0; i < [ttabs count]; i++) {
    id       tab;
    BOOL     isCurrentSelected;
    NSString *title;
    
    tab = [ttabs objectAtIndex:i];
    isCurrentSelected = i == selIdx;
    
    [self->selectedTab setValue:tab inComponent:sComponent];

    title = (self->tabNameKey)
      ? [self->tabNameKey stringValueInComponent:sComponent]
      : [tab stringValue];
    
    [_response appendContentString:@"<td"];
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:isCurrentSelected ? selColor : unselColor];
    [_response appendContentString:@"\""];
    [_response appendContentString:@">"];
    
    if (isInForm) {
      /* gen submit button */
      [_response appendContentString:@"<input type='submit' name=\""];
      [_response appendContentHTMLAttributeValue:[_ctx elementID]];
      [_response appendContentString:@"\" value=\""];
      [_response appendContentString:title];
      [_response appendContentString:
		   (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];
    }
    else {
      /* gen link */
      [_response appendContentString:@"<a href=\""];
      [_response appendContentHTMLAttributeValue:[_ctx componentActionURL]];
      [_response appendContentString:@"\" title=\""];
      [_response appendContentHTMLAttributeValue:title];
      [_response appendContentString:@"\">"];
      
      if (self->textColor != nil) {
        [_response appendContentString:@"<font color=\""];
        [_response appendContentHTMLAttributeValue:
                     [self->textColor stringValueInComponent:sComponent]];
        [_response appendContentString:@"\">"];
      }
      
      [_response appendContentHTMLString:title];

      if (self->textColor != nil)
        [_response appendContentString:@"</font>"];
      [_response appendContentString:@"</a>"];
    }
    
    [_response appendContentString:@"</td>"];
    
    [_ctx incrementLastElementIDComponent]; /* increment index */
  }
  [_ctx deleteLastElementIDComponent]; /* del index */
  [_ctx deleteLastElementIDComponent]; /* del 'tab' */

  [self->selectedTab setValue:[ttabs objectAtIndex:selIdx]
                     inComponent:sComponent];
  
  [_response appendContentString:@"</tr><tr><td colspan=\""];
  s = [[NSString alloc] initWithFormat:@"%d",[ttabs count]];
  [_response appendContentString:s];
  [s release];
  [_response appendContentString:@"\" bgcolor=\""];
  [_response appendContentString:selColor];
  [_response appendContentString:@"\">"];
  
  [_ctx appendElementIDComponent:@"content"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  
  [_response appendContentString:@"</td></tr></table>"];
}

@end /* WOTabPanel */
