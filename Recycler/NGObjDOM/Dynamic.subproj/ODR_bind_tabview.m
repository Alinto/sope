/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include <NGObjDOM/ODR_bind_tabview.h>
#ifdef __APPLE__
#include <NGObjWeb/WEClientCapabilities.h>
#else
#include <WEExtensions/WEClientCapabilities.h>
#endif

/*
   <var:tabview selection="selection"
                bgcolor="bgcolor"
                inactivecolor="inactivecolor"
                activecolor="activecolor"
                bgiconleft="inactivebgiconleft"
                bgicon="inactivebgicon"
                activebgicon="activebgicon">

     <tab const:title="tab 1" const:key="tab1">
       content of tab 1
     </tab>

     <tab const:title="tab 2" const:key="tab2">
       content of tab 2
     </tab>
   
   </var:tabview>

   tabview attributes:
     selection
     bgcolor
     inactivecolor
     activecolor
     bgiconleft
     bgicon
     activebgicon
     
   tab attributes:
     disabled - bool
     title    - String
     key      - String
     fontcolor
     fontface
     fontsize
*/

/* context keys */

#include "common.h"

@implementation ODR_bind_tabview

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->activeKey);
  [super dealloc];
}
#endif

- (void)_setActiveKey:(NSString *)_activeKey {
  ASSIGN(self->activeKey, _activeKey);
}

- (void)setActiveKey:(id)_node inContext:(WOContext *)_ctx {
  NSArray        *tabNodes;
  NSMutableArray *keys;
  int            i, cnt;

  [self _setActiveKey:[self stringFor:@"selection" node:_node ctx:_ctx]];
  keys      = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:8];
  tabNodes  = ODRLookupQueryPath(_node, @"-tab");
  cnt       = [tabNodes count];

  for (i=0; i < cnt; i++) {
    NSString *key = nil;
    id       tab;

    tab = [tabNodes objectAtIndex:i];
    key = [self stringFor:@"key" node:tab ctx:_ctx];
    if (key == nil) {
      key = [NSString stringWithFormat:@"%d", i];
      [self forceSetString:key for:@"key" node:tab ctx:_ctx];
    }
    [keys addObject:key];
  }
  /* selection is not available in keys */
  if (![keys containsObject:self->activeKey])
    [self _setActiveKey:nil];
  
  /* no or invalid selection, use first key */
  if ((self->activeKey == nil) && ([keys count] > 0))
    [self _setActiveKey:[[keys objectAtIndex:0] stringValue]];

  [self forceSetString:self->activeKey for:@"selection" node:_node ctx:_ctx];

  RELEASE(keys);  
}

/* responder */

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSArray  *tabs;
  unsigned i, cnt;
  
  /* set ODR_bind_tabview_ACTIVEKEY */
  [self setActiveKey:_node inContext:_ctx];

  tabs = ODRLookupQueryPath(_node, @"-tab");
  cnt  = [tabs count];
    
  [_ctx appendElementIDComponent:@"b"];
  [_ctx appendElementIDComponent:self->activeKey];
  
  for (i = 0; i < cnt; i++) {
    NSString *key;
    id       tab;

    tab = [tabs objectAtIndex:i];
    key = [self stringFor:@"key" node:tab ctx:_ctx];

    if ([key isEqualToString:self->activeKey]) {
      [super takeValuesForNode:tab fromRequest:_request inContext:_ctx];
      break;
    }
  }
  [_ctx deleteLastElementIDComponent]; // activeKey 
  [_ctx deleteLastElementIDComponent]; /* 'b' */
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *section;
  id       result = nil;
  
  if ((section = [_ctx currentElementID])) {
    /* header action */    
    if ([section isEqualToString:@"h"]) {
      
      [_ctx consumeElementID];
      
      [self forceSetString:[_ctx currentElementID]
            for:@"selection"
            node:_node
            ctx:_ctx];
      
    }
    /* body action */
    else if ([section isEqualToString:@"b"]) {
      NSString *selection;
      NSArray  *tabs;
      int      i, cnt;
      
      selection = [self stringFor:@"selection" node:_node ctx:_ctx];
      tabs      = ODRLookupQueryPath(_node, @"-tab");
      cnt       = [tabs count];
      
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:section];

      for (i = 0; i < cnt; i++) {
        NSString *key;
        id       tab;

        tab = [tabs objectAtIndex:i];
        key = [self stringFor:@"key" node:tab ctx:_ctx];

        if ([key isEqualToString:selection]) {
          [_ctx appendElementIDComponent:key];
          [_ctx consumeElementID];
          result = [super invokeActionForNode:tab
                          fromRequest:_request
                          inContext:_ctx];
          [_ctx deleteLastElementIDComponent];
          break;
        }
      }
      [_ctx deleteLastElementIDComponent];
    }
  }
  return result;
}

- (void)appendTab:(id)_tab
  node:(id)_node
  response:(WOResponse *)_response
  ctx:(WOContext *)_ctx
  left:(BOOL)_isLeft
{
  NSString *key       = nil;
  NSString *title     = nil;
  NSString *bgcolor   = nil;
  NSString *width     = nil;
  NSString *height    = nil;
  NSString *bgIcon    = nil;
  BOOL     isActive;
  NSString *tC, *tF, *tS; // text font attrtibutes
  BOOL     hasFont;


  key       = [self stringFor:@"key"   node:_tab ctx:_ctx];
  title     = [self stringFor:@"title" node:_tab ctx:_ctx];
  isActive  = [key isEqualToString:self->activeKey];
  
  width     = [self stringFor:@"width"  node:_node ctx:_ctx];
  height    = [self stringFor:@"height" node:_node ctx:_ctx];
  bgIcon    = (isActive)
    ? [self stringFor:@"activebgicon" node:_node ctx:_ctx]
    : ((_isLeft) ? [self stringFor:@"bgiconleft" node:_node ctx:_ctx]
                 : [self stringFor:@"bgicon"     node:_node ctx:_ctx]);
  bgIcon    = ODRUriOfResource(bgIcon, _ctx);
       
  bgcolor   = (isActive)
    ? [self stringFor:@"activecolor"   node:_node ctx:_ctx]
    : [self stringFor:@"inactivecolor" node:_node ctx:_ctx];
  
  title = (title) ? title : key;
  
  [_ctx appendElementIDComponent:key]; // append tab-key
  
  // append <td ...>
  [_response appendContentString:@"<td align=\"center\" valign=\"bottom\""];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  if (width) {
    [_response appendContentString:@" width=\""];
    [_response appendContentString:width];
    [_response appendContentCharacter:'"'];
  }
  if (height) {
    [_response appendContentString:@" height=\""];
    [_response appendContentString:height];
    [_response appendContentCharacter:'"'];
  }
  if (bgIcon) {
    [_response appendContentString:@" background=\""];
    [_response appendContentString:bgIcon];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];
  
  [_response appendContentString:@"<a href='"];
  [_response appendContentHTMLAttributeValue:[_ctx componentActionURL]];
  [_response appendContentString:@"' style=\"text-decoration: none;\">"];
  
  tC  = [self stringFor:@"fontcolor" node:_node ctx:_ctx];
  tF  = [self stringFor:@"fontface"  node:_node ctx:_ctx];
  tS  = [self stringFor:@"fontsize"  node:_node ctx:_ctx];
  
  hasFont = (tC || tF || tS) ? YES : NO;
  
  if (hasFont)
    ODRAppendFont(_response, tC, tF, tS);                      //   <font...>
  
  if (isActive)
    [_response appendContentString:@"<b>"];

  if (!(bgIcon || bgcolor))
    [_response appendContentString:@"["];
  
  [_response appendContentString:title];
  
  if (!(bgIcon || bgcolor))
    [_response appendContentString:@"]"];

  if (isActive)
    [_response appendContentString:@"</b>"];

  if (hasFont)
    [_response appendContentString:@"</font"];
  
  [_response appendContentString:@"</a>"];

  [_response appendContentString:@"</td>"];
  
  [_ctx deleteLastElementIDComponent]; // delete tab-key
}

- (void)appendHeaderFootRow:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  isLeftActive:(BOOL)_isLeftActive
{
  NSString *bgcolor = nil;
  
  /* header foot row */
  bgcolor = [self stringFor:@"bgcolor" node:_node ctx:_ctx];

  [_response appendContentString:@"<tr"];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentString:@"\""];
  }
  [_response appendContentString:@">"];
    
    /* left corner */
  [_response appendContentString:@"<td align=\"left\" width=\"10\">"];
  
  if (_isLeftActive)
    [_response appendContentString:@"&nbsp;"];
    
  if (!_isLeftActive) {
    NSString *uri;

    uri = [self stringFor:@"leftcornericon" node:_node ctx:_ctx];
    if ((uri = ODRUriOfResource(uri, _ctx))) {
      [_response appendContentString:@"<img border=\"0\" alt=\"\" src=\""];
      [_response appendContentString:uri];
      [_response appendContentString:@"\" />"];
    }
    else
      [_response appendContentString:@"&nbsp;"];
  }
  [_response appendContentString:@"</td>"];

  /* right corner */
  [_response appendContentString:@"<td align=\"right\">"];
  {
    NSString *uri;
    
    uri = [self stringFor:@"rightcornericon" node:_node ctx:_ctx];
    if ((uri = ODRUriOfResource(uri, _ctx))) {
      [_response appendContentString:@"<img border=\"0\" alt=\"\" src=\""];
      [_response appendContentString:uri];
      [_response appendContentString:@"\" />"];
    }
    else
      [_response appendContentString:@"&nbsp;"];
  }
  [_response appendContentString:@"</td>"];
    
  [_response appendContentString:@"</tr>"];
}

- (void)appendTabs:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSArray  *tabNodes;
  NSString *selection;
  BOOL     isLeftActive = NO, isFirst;
  unsigned i, count;
  
  [_ctx appendElementIDComponent:@"h"];

  tabNodes  = ODRLookupQueryPath(_node, @"-tab");
  selection = self->activeKey;
  
  /* generate header row */
  
  [_response appendContentString:@"<tr>"];
  [_response appendContentString:
               @"<td colspan='2'>"
               @"<table border='0' cellpadding='0' "
               @"cellspacing='0'><tr>"];
  
  for (i = 0, isFirst = YES, count = [tabNodes count]; i < count; i++) {
    NSString *key;
    id       tab;
    
    tab = [tabNodes objectAtIndex:i];
    
    if ([self boolFor:@"disabled" node:tab ctx:_ctx])
      continue;
    
    key = [self stringFor:@"key" node:tab ctx:_ctx];
    if (isFirst && [key isEqualToString:selection])
      isLeftActive = YES;
    
    [self appendTab:tab node:_node response:_response ctx:_ctx left:isFirst];
    isFirst = NO;
  }
  [_response appendContentString:@"</tr></table></td></tr>"];
  
  [_ctx deleteLastElementIDComponent];
  
  [self appendHeaderFootRow:_node
        toResponse:_response
        inContext:_ctx
        isLeftActive:isLeftActive];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString     *bgcolor;

  [self setActiveKey:_node inContext:_ctx];

  /* start appending */
  [_response appendContentString:
               @"<table border='0' width='100%'"
               @" cellpadding='0' cellspacing='0'>"];
  
  /* appending tabs */

  [self appendTabs:_node toResponse:_response inContext:_ctx];

  bgcolor   = [self stringFor:@"bgcolor" node:_node ctx:_ctx];

  /* append body row */
  {
    [_response appendContentString:@"<tr><td colspan='2'"];
    if (bgcolor) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentHTMLAttributeValue:bgcolor];
      [_response appendContentString:@"\""];
    }
    [_response appendContentString:@">"];
    
    if (/*indentContent*/ YES) {
      /* start padding table */
      [_response appendContentString:
                   @"<table border='0' width='100%'"
                   @" cellpadding='10' cellspacing='0'>"];
      [_response appendContentString:@"<tr><td>"];
    }
    
    [_ctx appendElementIDComponent:@"b"];
    
    /* generate currently active body */
    {
      NSArray *tabs;
      int     i, cnt;
      
      tabs = ODRLookupQueryPath(_node, @"-tab");
      cnt  = [tabs count];
      
      [_ctx appendElementIDComponent:self->activeKey];
      for (i=0; i<cnt; i++) {
        NSString *key;
        id       tab;

        tab = [tabs objectAtIndex:i];
        key = [self stringFor:@"key" node:tab ctx:_ctx]; 
        if ([key isEqualToString:self->activeKey]) {
          [super appendNode:tab toResponse:_response inContext:_ctx];
          break;
        }
      }
      [_ctx deleteLastElementIDComponent];
    }
    
    [_ctx deleteLastElementIDComponent];
    
    if (/*indentContent*/ YES)
      /* close padding table */
      [_response appendContentString:@"</td></tr></table>"];
    
    [_response appendContentString:@"</td></tr>"];
  }
  
  [_response appendContentString:@"</table>"];
}

@end /* ODR_bind_tabview */
