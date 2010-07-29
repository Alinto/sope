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

@interface WETableMatrixContentImp : WODynamicElement
{
  WOAssociation *elementName;
  WOAssociation *rowspan;     /* a write variable */
  WOAssociation *colspan;     /* a write variable */
  
  WOElement     *template;
}
@end

@interface WETableMatrixContent : WETableMatrixContentImp
@end

@interface WETableMatrixNoContent : WETableMatrixContentImp
@end

#include <NGObjWeb/NGObjWeb.h>
#include "common.h"

@implementation WETableMatrixContentImp

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->elementName = WOExtGetProperty(_config, @"elementName");
    self->rowspan     = WOExtGetProperty(_config, @"rowspan");
    self->colspan     = WOExtGetProperty(_config, @"colspan");
    
    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->rowspan);
  RELEASE(self->colspan);
  RELEASE(self->elementName);
  RELEASE(self->template);
  [super dealloc];
}

/* accessors */

- (NSString *)modeKey {
  [self logWithFormat:@"ERROR: subclasses should override -modeKey!"];
  return nil;
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  id       tmp;
  NSString *tag;
  int      cspan, rspan;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  if ((tmp = [_ctx valueForKey:@"WETableMatrix_Query"])) {
    [tmp addObject:[self modeKey]];
    return;
  }
  
  if ((tmp = [_ctx valueForKey:@"WETableMatrix_Mode"]) == nil)
    return;

  if (![tmp isEqualToString:[self modeKey]])
    return;

  cspan = [[_ctx objectForKey:@"WETableMatrix_ColSpan"] intValue];
  if (cspan < 1) cspan = 1;
  rspan = [[_ctx objectForKey:@"WETableMatrix_RowSpan"] intValue];
  if (rspan < 1) rspan = 1;
  
  if ([self->colspan isValueSettable]) {
    [self->colspan setValue:[NSNumber numberWithInt:cspan]
                   inComponent:[_ctx component]];
  }
  if ([self->rowspan isValueSettable]) {
    [self->rowspan setValue:[NSNumber numberWithInt:rspan]
                   inComponent:[_ctx component]];
  }
  
  tag = [self->elementName stringValueInComponent:[_ctx component]];

  if (tag) {
    NSString *s;
    char buf[64];
    
    [_response appendContentString:@"<"];
    [_response appendContentString:tag];

    if (cspan > 1) {
      sprintf(buf, "%i", cspan);
      s = [[NSString alloc] initWithCString:buf];
      [_response appendContentString:@" colspan=\""];
      [_response appendContentString:s];
      [_response appendContentString:@"\""];
      [s release];
    }
    if (rspan > 1) {
      sprintf(buf, "%i", rspan);
      s = [[NSString alloc] initWithCString:buf];
      [_response appendContentString:@" rowspan=\""];
      [_response appendContentString:s];
      [_response appendContentString:@"\""];
      [s release];
    }

    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    
    [_response appendContentString:@">"];
  }
  
  [self->template appendToResponse:_response inContext:_ctx];

  if (tag) {
    [_response appendContentString:@"</"];
    [_response appendContentString:tag];
    [_response appendContentString:@">"];
  }
}

@end /* WETableMatrixContentImp */

@implementation WETableMatrixContent

- (NSString *)modeKey {
  return @"content";
}

@end /* WETableMatrixContent */

@implementation WETableMatrixNoContent

- (NSString *)modeKey {
  return @"empty";
}

@end /* WETableMatrixNoContent */
