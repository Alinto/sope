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

@interface WETableMatrixLabel : WODynamicElement
{
  WOAssociation *position;    /* top, bottom, left, right, topleft */
  WOAssociation *elementName;
  WOAssociation *span;
  WOAssociation *string;
  
  WOElement     *template;
}
@end

#include <NGObjWeb/NGObjWeb.h>
#include "common.h"

@implementation WETableMatrixLabel

static Class    StrClass  = Nil;

+ (void)initialize {
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  StrClass = [NSString class];
}

static NSString *retStrForInt(int i) {
  switch(i) {
  case 0:  return @"0";
  case 1:  return @"1";
  case 2:  return @"2";
  case 3:  return @"3";
  case 4:  return @"4";
  case 5:  return @"5";
  case 6:  return @"6";
  case 7:  return @"7";
  case 8:  return @"8";
  case 9:  return @"9";
  case 10: return @"10";
    // TODO: find useful count!
  default:
    return [[StrClass alloc] initWithFormat:@"%i", i];
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->position = WOExtGetProperty(_config, @"position");
    if (self->position == nil)
      self->position = [[WOAssociation associationWithValue:@"top"] retain];

    self->elementName = WOExtGetProperty(_config, @"elementName");
    self->span        = WOExtGetProperty(_config, @"span");
    self->string      = WOExtGetProperty(_config, @"string");
    
    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->string      release];
  [self->span        release];
  [self->elementName release];
  [self->position    release];
  [self->template    release];
  [super dealloc];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *pos;
  id       tmp;
  NSString *tag;
  int      ispan;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  pos = [self->position stringValueInComponent:[_ctx component]];
  
  if ((tmp = [_ctx valueForKey:@"WETableMatrix_Query"]) != nil) {
    if (pos == nil)
      [self errorWithFormat:@"got no position: %@", self->position];
    else
      [tmp addObject:pos];
    return;
  }

  if ((tmp = [_ctx valueForKey:@"WETableMatrix_Mode"]) == nil)
    return;

  if (![tmp isEqualToString:pos])
    return;

  /* check span (some kind of condition) */
  
  ispan = [self->span intValueInComponent:[_ctx component]];
  if (ispan < 1) ispan = 1;
  
  if (ispan > 1) {
    int idx;

    idx = [[_ctx objectForKey:@"WETableMatrix_Index"] intValue];
    if (idx % ispan != 0)
      /* the label is not active in that column/row */
      return;
  }
  else if (ispan < 1)
    ispan = 1;
  
  tag = [self->elementName stringValueInComponent:[_ctx component]];
  
  if (tag) {
    NSString *s;
    int rspan, cspan;
    
    [_response appendContentString:@"<"];
    [_response appendContentString:tag];
    
    rspan = [[_ctx objectForKey:@"WETableMatrix_RowSpan"] intValue];
    cspan = [[_ctx objectForKey:@"WETableMatrix_ColSpan"] intValue];
    
    if (rspan > 1) {
      [_response appendContentString:@" rowspan=\""];
      s = retStrForInt(rspan);
      [_response appendContentString:s];
      [s release];
      [_response appendContentString:@"\""];
    }
    if (cspan > 1) {
      [_response appendContentString:@" colspan=\""];
      s = retStrForInt(cspan);
      [_response appendContentString:s];
      [s release];
      [_response appendContentString:@"\""];
    }
    
    if (ispan > 1) {
      if ([tmp isEqualToString:@"bottom"] || [tmp isEqualToString:@"top"]) {
        [_response appendContentString:@" colspan=\""];
        NSAssert(cspan <= 1, @"double row-span !!");
      }
      else {
        [_response appendContentString:@" rowspan=\""];
        NSAssert(rspan <= 1, @"double row-span !!");
      }
      s = retStrForInt(ispan);
      [_response appendContentString:s];
      [s release];
      [_response appendContentString:@"\""];
    }

    if ([tmp isEqualToString:@"top"]) {
      int    count;
      double width;
      char   buf[64];
      NSString *s;

      count = [[_ctx objectForKey:@"WETableMatrix_Count"] intValue];
      width = 100.0 / ((double)count / (double)ispan);
      
      sprintf(buf, "%.0f", width);
      s = [[StrClass alloc] initWithCString:buf];
      
      [_response appendContentString:@" width=\""];
      [_response appendContentString:s];
      [_response appendContentString:@"%\""];
      
      [s release];
    }
    
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    [_response appendContentString:@">"];
  }
  
  if (self->string) {
    NSString *s;
    s = [self->string stringValueInComponent:[_ctx component]];
    [_response appendContentHTMLString:s];
  }
  [self->template appendToResponse:_response inContext:_ctx];
  
  if (tag) {
    [_response appendContentString:@"</"];
    [_response appendContentString:tag];
    [_response appendContentString:@">"];
  }
}

@end /* WETableMatrixLabel */
