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

#include "WETableCell.h"

@interface WETableData : WETableCell
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *title;   // title
  WOAssociation *align;   // align
  WOAssociation *valign;  // valign
  WOAssociation *isGroup; // show data content?
}

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c;

@end /* WETableData */

@interface _WEComplexTableData : WETableData
{
  WOAssociation *string;       // string content
  WOAssociation *value;        // object content (can be formatted)
  WOAssociation *numberformat; // string
  WOAssociation *dateformat;   // string
  WOAssociation *formatter;    // WO4: NSFormatter object
  WOAssociation *action;       // 
}

@end

#include "WETableView.h"
#import "common.h"
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSDateFormatter.h>

@implementation WETableData

+ (int)version {
  return [super version] + 1 /* v3 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->isGroup = WOExtGetProperty(_config, @"isGroup");
    self->title   = WOExtGetProperty(_config, @"title");
    self->align   = WOExtGetProperty(_config, @"align");
    self->valign  = WOExtGetProperty(_config, @"valign");
    if (self->valign == nil)
      self->valign = [[WOAssociation associationWithValue:@"TOP"] retain];
  }
  return self;
}
- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  /* cluster */
  if (([_config objectForKey:@"string"] != nil) ||
      ([_config objectForKey:@"value"] != nil)) {
    [self release];
    return [[_WEComplexTableData alloc] _initWithName:_name
                                        associations:_config
                                        template:_c];
  }

  return [self _initWithName:_name associations:_config template:_c];
}

- (void)dealloc {
  [self->title   release];
  [self->isGroup release];
  [self->align   release];
  [self->valign  release];
  [super dealloc];
}

- (void)_collectDataInContext:(WOContext *)_ctx {
  WOComponent      *cmp;
  NSMutableArray   *infos;
  WETableViewInfo  *info;
  NSString         *key;
  NSString         *sortedKey;

  cmp       = [_ctx component];
  infos     = [_ctx objectForKey:WETableView_INFOS];
  key       = [self->sortKey valueInComponent:cmp];
  sortedKey = [_ctx objectForKey:WETableView_SORTEDKEY];

  
  if (infos == nil) {
    infos = [NSMutableArray arrayWithCapacity:4];
    [_ctx setObject:infos forKey:WETableView_INFOS];
  }
  info = [[WETableViewInfo alloc] init];
  info->rowSpan  = 1;
  info->isGroup  = [self->isGroup boolValueInComponent:cmp];
  info->isSorted = (key != nil && sortedKey != nil && [key isEqual:sortedKey]);

  [infos addObject:info];
  [info release]; info = nil;
}

- (void)_appendHeader:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *bg; // bgcolor
  NSString    *t;  // title
  NSString    *tC, *tF, *tS; // text font attrtibutes
  NSString    *a;  // align
  BOOL        hasFont;

  cmp = [_ctx component];
  
  tC  = [_ctx objectForKey:WETableView_fontColor];
  tF  = [_ctx objectForKey:WETableView_fontFace];
  tS  = [_ctx objectForKey:WETableView_fontSize];
  a   = [self->align stringValueInComponent:cmp];

  hasFont = (tC || tF || tS) ? YES : NO;

  bg = [_ctx objectForKey:WETableView_headerColor];
  t  = [self->title stringValueInComponent:cmp];

  WEAppendTD(_response, a, nil, bg);                     // <td...>
  [_response appendContentString:@"<nobr />"];
  
  [self appendSortIcon:_response inContext:_ctx];

  if (t) {
    if (hasFont)
      WEAppendFont(_response, tC, tF, tS);               //   <font...>
   
    [_response appendContentString:@" <b>"];
    [_response appendContentString:t];
    [_response appendContentString:@"</b>"];

    if (hasFont)
      [_response appendContentString:@"</font>"];        //   </font>
  }
  [_response appendContentString:@"</nobr>"];
  [_response appendContentString:@"</td>"];              // </td>
}

- (void)_appendStringContentToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
}

- (void)_appendData:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  info:(WETableViewInfo *)_info
{
  WOComponent *cmp;
  NSString    *bg, *a, *va;
  NSString    *tC, *tF, *tS; // text font attrtibutes
  BOOL        hasFont;
  
  if (_info->isGroup)
    return;

  cmp = [_ctx component];
  bg  = [self->bgColor stringValueInComponent:cmp];
  a   = [self->align   stringValueInComponent:cmp];
  va  = [self->valign  stringValueInComponent:cmp];
    
  tC  = [_ctx objectForKey:WETableView_fontColor];
  tF  = [_ctx objectForKey:WETableView_fontFace];
  tS  = [_ctx objectForKey:WETableView_fontSize];
  hasFont = (tC || tF || tS) ? YES : NO;
    
  if (bg == nil) {
    bg = (_info->isEven)
      ? [_ctx objectForKey:WETableView_evenColor]
      : [_ctx objectForKey:WETableView_oddColor];
  }
    
  [_response appendContentString:@"<td "];          // <td...>
  if (bg) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bg];
    [_response appendContentCharacter:'"'];
  }
  if (_info->rowSpan > 1) {
    switch (_info->rowSpan) {
    case 0:
      [_response appendContentString:@" rowspan=\"0\""];
      break;
    case 1:
      [_response appendContentString:@" rowspan=\"1\""];
      break;
    case 2:
      [_response appendContentString:@" rowspan=\"2\""];
      break;
    default: {
      NSString *s;
      s = [[NSString alloc] initWithFormat:@"%i", _info->rowSpan];
      [_response appendContentString:@" rowspan=\""];
      [_response appendContentString:s];
      [_response appendContentCharacter:'"'];
      [s release];
      break; }
    }
  }
  if (a) {
    [_response appendContentString:@" align=\""];
    [_response appendContentString:a];
    [_response appendContentCharacter:'"'];
  }
  if (va) {
    [_response appendContentString:@" valign=\""];
    [_response appendContentString:va];
    [_response appendContentCharacter:'"'];
  }
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentCharacter:'>'];
    
  if (hasFont)
    WEAppendFont(_response, tC, tF, tS);                      //   <font...>
  [self->template appendToResponse:_response inContext:_ctx];

  [self _appendStringContentToResponse:_response inContext:_ctx];
  if (hasFont)
    [_response appendContentString:@"</font>"];                 // </font>

  [_response appendContentString:@"</td>"];                  // </td>
}

/* responder */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  if ([_ctx objectForKey:WETableView_CollectMode]) {
    [self _collectDataInContext:_ctx];
    return;
  }
  
  if ([_ctx objectForKey:WETableView_HeaderMode] && self->title) {
    [self _appendHeader:_response inContext:_ctx];
  }
  else if ([[_ctx objectForKey:WETableView_DataMode] boolValue]) {
    NSMutableArray *infos = nil;

    infos  = [_ctx objectForKey:WETableView_INFOS];

    if (infos != nil && [infos count] > 0) {
      [self _appendData:_response inContext:_ctx info:[infos objectAtIndex:0]];
      [infos removeObjectAtIndex:0];
    }
  }
}

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if ([[_ctx objectForKey:WETableView_DataMode]   boolValue] ||
      [[_ctx objectForKey:WETableView_HeaderMode] boolValue]) {
    [super takeValuesFromRequest:_rq inContext:_ctx];
  }
}

@end /* WETableData */

@implementation _WEComplexTableData

- (id)_initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super _initWithName:_name associations:_config template:_c])) {
    self->string       = WOExtGetProperty(_config, @"string");
    self->value        = WOExtGetProperty(_config, @"value");
    self->formatter    = WOExtGetProperty(_config, @"formatter");
    self->numberformat = WOExtGetProperty(_config, @"numberformat");
    self->dateformat   = WOExtGetProperty(_config, @"dateformat");
    self->action       = WOExtGetProperty(_config, @"action");
    
    /* check formats */
    {
      int num = 0;
      if (self->formatter    != nil) num++;
      if (self->numberformat != nil) num++;
      if (self->dateformat   != nil) num++;
      if (num > 1) {
        [self warnWithFormat:
		@"more than one formats specified in element: %@", self];
      }
    }
  }
  return self;
}

- (void)dealloc {
  [self->formatter    release];
  [self->numberformat release];
  [self->dateformat   release];
  [self->string       release];
  [self->value        release];
  [self->action       release];
  [super dealloc];
}

/* generate response */

- (NSFormatter *)retainedFormatterInContext:(id)_ctx {
  NSFormatter *fmt;
  id s;
  
  if (self->numberformat != nil) {
    fmt = [[NSNumberFormatter alloc] init];
    s = [self->numberformat valueInComponent:[_ctx component]];
    [(NSNumberFormatter *)fmt setFormat:s];
    return fmt;
  }
  
  if (self->dateformat != nil) {
    s = [self->dateformat valueInComponent:[_ctx component]];
    fmt = [[NSDateFormatter alloc] initWithDateFormat:s
				   allowNaturalLanguage:NO];
    return fmt;
  }
  
  if (self->formatter != nil) {
    fmt = [self->formatter valueInComponent:[_ctx component]];
#ifdef DEBUG
    if (fmt && ![fmt respondsToSelector:@selector(stringForObjectValue:)]) {
      [self logWithFormat:@"invalid formatter determined by keypath %@: %@",
	      self->formatter, fmt];
    }
#endif
    return [fmt retain];
  }
  
  return nil;
}

- (void)_appendStringContentToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *cmp;
  NSString    *s;
  NSString    *tC, *tF, *tS; // text font attrtibutes
  BOOL        hasFont;
  
  cmp = [_ctx component];

  tC  = [_ctx objectForKey:WETableView_fontColor];
  tF  = [_ctx objectForKey:WETableView_fontFace];
  tS  = [_ctx objectForKey:WETableView_fontSize];
  hasFont = (tC || tF || tS) ? YES : NO;
  
  if (self->action != nil) {
    [_ctx appendElementIDComponent:@"act"];
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];
  }
  if (hasFont)
    WEAppendFont(_response, tC, tF, tS);                      //   <FONT...>
  
  /* add value */
  
  if (self->value != nil) {
    NSFormatter *fmt = nil;
    id          obj;
    
    obj = [self->value valueInComponent:cmp];
    
    if ((fmt = [self retainedFormatterInContext:_ctx]) != nil) {
      s = [fmt stringForObjectValue:obj];
      [fmt release];
    }
    else
      s = [obj stringValue];
    
    if (s != nil) [_response appendContentHTMLString:s];
  }
  
  /* add string */
  
  if (self->string != nil) {
    s = [self->string stringValueInComponent:cmp];
    [_response appendContentHTMLString:s];
  }
  if (hasFont)
    [_response appendContentString:@"</font>"];                 // </font>
  
  if (self->action != nil) {
    [_ctx deleteLastElementIDComponent]; // delete 'act'
    [_response appendContentString:@"</a>"];
  }
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx
{
  NSString *eid;

  eid = [_ctx currentElementID];

  return ([eid isEqualToString:@"act"])
    ? [self->action valueInComponent:[_ctx component]]
    : [super invokeActionForRequest:_request inContext:_ctx];
}

@end /* _WEComplexTableData */
