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

/*
  WEBrowser
  
  TODO: document

  API:
    - extra attributes are attributes of the <table> tag
*/

@interface WEBrowser : WODynamicElement
{
@protected
  WOAssociation *list;
  WOAssociation *item;
  WOAssociation *sublist;
  WOAssociation *currentPath;
  
  // config
  WOAssociation *bgColor;
  WOAssociation *height;
  WOAssociation *columnWidth;
  
  WOElement     *template;
}
@end

#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

static NSString *WEBrowser_Plus    = @"WEBrowser_Plus";
static NSString *WEBrowser_Minus   = @"WEBrowser_Minus";

@implementation WEBrowser

#if 0
static NSString *retStrForInt(int i) {
  return [[NSString alloc] initWithFormat:@"%i", i];
}
#endif

static inline void
_applyPath(WEBrowser *self, NSArray *path, WOComponent *cmp) {
  [self->currentPath setValue:path              inComponent:cmp];
  [self->item        setValue:[path lastObject] inComponent:cmp];
}

static inline void
_applyPathAppenedByItem(WEBrowser *self, NSArray *path, id obj, id cmp) {
  [self->currentPath setValue:[path arrayByAddingObject:obj] inComponent:cmp];
  [self->item        setValue:obj                            inComponent:cmp];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_root
{
  if ((self=[super initWithName:_name associations:_config template:_root])) {
    self->list        = WOExtGetProperty(_config, @"list");
    self->item        = WOExtGetProperty(_config, @"item");
    self->sublist     = WOExtGetProperty(_config, @"sublist");
    self->currentPath = WOExtGetProperty(_config, @"currentPath");

    // config
    self->bgColor     = WOExtGetProperty(_config, @"bgColor");
    self->height      = WOExtGetProperty(_config, @"height");
    self->columnWidth = WOExtGetProperty(_config, @"columnWidth");

    self->template  = [_root retain];
  }
  return self;
}

- (void)dealloc {
  [self->list        release];
  [self->item        release];
  [self->sublist     release];
  [self->currentPath release];

  [self->columnWidth release];
  [self->bgColor     release];
  [self->height      release];
  
  [self->template release];
  [super dealloc];
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
#if 0
  [self->template takeValuesFromRequest:_req inContext:_ctx];
#endif
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent    *cmp;
  NSMutableArray *stack;
  NSArray        *selects;
  NSArray        *subarray;
  NSString       *cid;
  id             result;
  id             obj = nil;
  int            col, row;
  BOOL           isScroll = NO;

  cmp     = [_ctx component];
  selects = [self->currentPath valueInComponent:cmp];

  cid = [_ctx currentElementID];
  
  if ([cid isEqualToString:@"scroll"]) {
    isScroll = YES;

    [_ctx appendElementIDComponent:cid];   // append scroll
    cid = [_ctx consumeElementID];         // get currentPath index (=column)
    col = [cid intValue];                  //
    [_ctx appendElementIDComponent:cid];   // append column
    cid = [_ctx consumeElementID];         // get row
    row = [cid intValue];
    [_ctx appendElementIDComponent:cid];   // append row
    cid = [_ctx consumeElementID];         // get plus or minus action or else
  }
  else {
    cid = [_ctx currentElementID];         // get row
    row = [cid  intValue];
    [_ctx appendElementIDComponent:cid];   // append row
    cid = [_ctx consumeElementID];         // get currentPath index (=column)
    col = [cid intValue];
    [_ctx appendElementIDComponent:cid];   // append index
    cid = [_ctx consumeElementID];         // get plus or minus action or else
  }

  stack = [NSMutableArray arrayWithArray:
                          [selects subarrayWithRange:NSMakeRange(0, col)]];

  if ([cid isEqual:WEBrowser_Minus]) {
    // last object of current path is the clicked one
    if (col < (int)[selects count]) {
      [self->currentPath setValue:stack              inComponent:cmp];
      [self->item        setValue:[stack lastObject] inComponent:cmp];
    }
    result = nil;
  }
  else {

    // prepare for getting the clicked object
    if (col == 0)
      subarray = [self->list valueInComponent:cmp];
    else {
      obj = [selects objectAtIndex:col-1];
      [self->item        setValue:obj   inComponent:cmp];
      [self->currentPath setValue:stack inComponent:cmp];
      
      subarray = [self->sublist valueInComponent:cmp];
    }
    // get clicked object and update currentPath (=stack)
    if (row < (int)[subarray count]) {
      obj = [subarray objectAtIndex:row];
      [stack addObject:obj];
    }
    
    [self->currentPath setValue:stack inComponent:cmp];
    [self->item        setValue:obj   inComponent:cmp];
  
    if ([cid isEqual:WEBrowser_Plus])
      result = nil;
    else
      result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  [_ctx deleteLastElementIDComponent];   // delete row
  [_ctx deleteLastElementIDComponent];   // delete index

  return result;
}

- (BOOL)_useScrollingInContext:(WOContext *)_ctx {
  return [[[_ctx request] clientCapabilities] doesSupportCSSOverflow];
}

- (void)appendWithScrolling:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent *cmp     = nil;
  NSArray     *selects = nil;
  NSArray     *path    = nil;
  int         columns, cnt, i, j;
  BOOL        useScrolling;

  useScrolling = [self _useScrollingInContext:_ctx];
  
  cmp = [_ctx component];
  
  if ((selects = [[self->currentPath valueInComponent:cmp] copy]) == nil) {
    selects = [[NSArray alloc] init];
    [self->currentPath setValue:selects inComponent:cmp];
  }
  
  columns   = [selects count] + 1;

  [_resp appendContentString:@"<table"];
  [self appendExtraAttributesToResponse:_resp inContext:_ctx];
  [_resp appendContentString:@">"];
  
  [_resp appendContentString:@"<tr>"];
  
  [_ctx appendElementIDComponent:@"scroll"]; // scroll - mode
  
  [_ctx appendZeroElementIDComponent];
  for (i=0; i < columns; i++) {
    NSArray *array;
    
    path = [selects subarrayWithRange:NSMakeRange(0, i)];
    _applyPath(self, path, cmp);
    
    array = (i == 0)
      ? [self->list valueInComponent:cmp]
      : [self->sublist valueInComponent:cmp];
    cnt = [array count];
      
    if (cnt) {
      [_resp appendContentString:@"<td valign=\"top\""];
      if (self->columnWidth) {
        [_resp appendContentString:@" width=\""];
        [_resp appendContentHTMLAttributeValue:
                 [self->columnWidth stringValueInComponent:cmp]];
        [_resp appendContentString:@"\""];
      }
      [_resp appendContentCharacter:'>'];
      if (self->height && useScrolling) {
        [_resp appendContentString:@"<p style=\"width:100%; height="];
        [_resp appendContentString:[self->height stringValueInComponent:cmp]];
        [_resp appendContentString:@"; overflow-y: auto;\">"];
      }
      [_resp appendContentString:
               @"<table width=\"100%\" border=\"0\" "
               @"cellspacing=\"0\" cellpadding=\"2\">"];
    
      [_ctx appendZeroElementIDComponent];
      for (j = 0; j < cnt; j++) {
        NSString *bg = nil;
        id       obj = nil;

        obj = [array objectAtIndex:j];
        _applyPathAppenedByItem(self, path, obj, cmp);
        bg = [self->bgColor stringValueInComponent:cmp];
        
        [_resp appendContentString:@"<tr><td valign=\"center\""];
        if (bgColor) {
          [_resp appendContentString:@" bgcolor=\""];
          [_resp appendContentHTMLAttributeValue:bg];
          [_resp appendContentCharacter:'"'];
        }
        [_resp appendContentString:@">"];
        
#if 0
        // named ankers for 'jump-to' functionality
        [_resp appendContentString:@"<a name=\""];
        s = retStrForInt(j);
        [_resp appendContentString:s];
        [s release];
        [_resp appendContentString:@"\">"];
        s = retStrForInt(j);
        [_resp appendContentString:s];
        [s release];
        [_resp appendContentString:@"</a>"];
#endif
        
        [self->template appendToResponse:_resp inContext:_ctx];

        [_resp appendContentString:@"</td></tr>"];
        [_ctx incrementLastElementIDComponent];
      }
      [_ctx deleteLastElementIDComponent];

      [_resp appendContentString:@"</table>"];
      if (self->height && useScrolling)
        [_resp appendContentString:@"</p>"];
      [_resp appendContentString:@"</td>"];
    }
    [_ctx incrementLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent];
  [_resp appendContentString:@"</tr></table>"];

  [_ctx deleteLastElementIDComponent]; // delete scroll-mode
  
  [self->currentPath setValue:selects inComponent:cmp];
  
  [selects release]; selects = nil;
}

- (void)appendWithoutScrolling:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent    *cmp     = nil;
  NSArray        *selects = nil;
  NSArray        *array   = nil;
  NSMutableArray *path    = nil;
  NSString       *bg      = nil;
  int            selectCnt, cnt, i, j;
  
  NSAssert(self->currentPath,
           @"WEBrowser: missing 'currentPath' association!");
  
  cmp       = [_ctx component];
  array     = [self->list valueInComponent:cmp];
  selects   = [[self->currentPath valueInComponent:cmp] copy];

  cnt       = [array count];
  selectCnt = [selects count] + 1;
  path      = [NSMutableArray arrayWithCapacity:selectCnt];
  
  [_resp appendContentString:@"<table"];
  [self appendExtraAttributesToResponse:_resp inContext:_ctx];
  [_resp appendContentString:@">"];
  
  [_ctx appendZeroElementIDComponent];
  for (i = 0; i < cnt; i++) {
    [_resp appendContentString:@"<tr>"];
    
    [_ctx appendZeroElementIDComponent];
    
    for (j = 0; j < selectCnt; j++) {
      NSArray *subarray;
      int     subCount;

      [path removeAllObjects];
      [path addObjectsFromArray:
            [selects subarrayWithRange:NSMakeRange(0, j)]];

      // get subarray
      if (j == 0) {
        subarray = array;
      }
      else {
        id obj;
        obj = [selects objectAtIndex:j-1];
        [self->item        setValue:obj  inComponent:cmp];
        [self->currentPath setValue:path inComponent:cmp];
        subarray = [self->sublist valueInComponent:cmp];
      }
      // update cnt
      subCount = [subarray count];
      cnt      = (subCount > cnt) ? subCount : cnt;

      // append template
      if (subCount > i) {
        NSString *k;
        id       obj;

        obj = [subarray objectAtIndex:i];
        [self->item        setValue:obj  inComponent:cmp];
        // [self->currentPath setValue:path inComponent:cmp];

        // is current object in currentPath?
        
        if ((j < (int)[selects count]) && 
            [[selects objectAtIndex:j] isEqual:obj]) {
          k = (j < selectCnt-1)
            ? WEBrowser_Minus
            : WEBrowser_Plus;
        }
        else
          k = WEBrowser_Plus;
        
        bg = [self->bgColor stringValueInComponent:cmp];

        WEAppendTD(_resp, nil, nil, bg);
        [path addObject:obj];
        [self->currentPath setValue:path inComponent:cmp];
        [self->template appendToResponse:_resp inContext:_ctx];
        [_resp appendContentString:@"</td>"];
      }
      else {
        [_resp appendContentString:@"<td colspan=\"2\""];
        [self->currentPath setValue:nil inComponent:cmp];
        [self->item        setValue:nil inComponent:cmp];
        bg = [self->bgColor stringValueInComponent:cmp];
        if (bg) {
          [_resp appendContentString:@" bgcolor=\""];
          [_resp appendContentString:bg];
        }
        [_resp appendContentString:@"\">&nbsp;</td>"];
      }
      [_ctx incrementLastElementIDComponent];
    }
    [_ctx deleteLastElementIDComponent];
    [_resp appendContentString:@"</tr>"];
    [_ctx incrementLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent];
  [_resp appendContentString:@"</table>"];

  [self->currentPath setValue:selects inComponent:cmp];
  [selects release];
}

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_resp inContext:_ctx];
    return;
  }
  
#if 1
  [self appendWithScrolling:_resp inContext:_ctx];
#else
  if ([self _useScrollingInContext:_ctx])
    [self appendWithScrolling:_resp inContext:_ctx];
  else
    [self appendWithoutScrolling:_resp inContext:_ctx];
#endif
}

@end /* WEBrowser */
