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
  WOTable
  
  TODO: document
*/
@interface WOTable : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *list;        // array of objects to iterate through
  WOAssociation *item;        // current item in the array
  WOAssociation *maxColumns;  // number of columns
  WOAssociation *index;       // current index
  WOAssociation *col;         // current column (is updated with each iteration)
  WOAssociation *row;         // current row    (is updated with each iteration)

  WOAssociation *cellAlign;   // current cell align
  WOAssociation *cellVAlign;  // current cell valign
  WOAssociation *rowBackgroundColor;  // current row background color;
  WOAssociation *cellBackgroundColor; // current cell background color;

  /*
    table attributes are implemented as extraAttributes:
     
         tableBackgroundColor, --> bgColor
         border,               --> border
         cellpadding,          --> cellpadding
         cellspacing,          --> cellspacing
  */
  
  /* non WO attribute */
  WOAssociation *horizontal;   // order items horizontal (default = NO)
  WOAssociation *hasOwnTDs;    // don't draw TDs

  WOElement     *template;
}
@end

#include "common.h"

static NSString *_WOTableHeaderString_  = @"_WOTableHeaderString_";
static NSString *_WOTableContentString_ = @"_WOTableContentString_";
static NSString *_WOTableContextMode_   = @"_WOTableContextMode_";

@implementation WOTable

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->list       = WOExtGetProperty(_config, @"list");
    self->item       = WOExtGetProperty(_config, @"item");
    self->maxColumns = WOExtGetProperty(_config, @"maxColumns");
    self->index      = WOExtGetProperty(_config, @"index");
    self->col        = WOExtGetProperty(_config, @"col");
    self->row        = WOExtGetProperty(_config, @"row");
    self->horizontal = WOExtGetProperty(_config, @"horizontal");
    self->hasOwnTDs  = WOExtGetProperty(_config, @"hasOwnTDs");

    self->cellAlign  = WOExtGetProperty(_config, @"cellAlign");
    self->cellVAlign = WOExtGetProperty(_config, @"cellVAlign");
    
    self->rowBackgroundColor  = 
      WOExtGetProperty(_config, @"rowBackgroundColor");
    self->cellBackgroundColor = 
      WOExtGetProperty(_config, @"cellBackgroundColor");

    self->template = RETAIN(_c);
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  
  [self->list       release];
  [self->item       release];
  [self->maxColumns release];
  [self->index      release];
  [self->col        release];
  [self->row        release];
  [self->horizontal release];
  [self->hasOwnTDs  release];

  [self->cellAlign           release];
  [self->cellVAlign          release];
  [self->rowBackgroundColor  release];
  [self->cellBackgroundColor release];
  [super dealloc];
}

static inline void _applyIndex(WOTable *self, WOComponent *cmp, unsigned _idx)
{
  NSArray  *array;
  BOOL     isHor;
  unsigned r, c, cnt, cols;

  isHor = [self->horizontal boolValueInComponent:cmp];
  cols  = [self->maxColumns unsignedIntValueInComponent:cmp];
  array = [self->list valueInComponent:cmp];
  cnt   = [array count];
  cols  = (cols) ? cols : 1;
  r     = (isHor) ? (_idx / cols) + 1 : _idx % ((cnt / cols)+1) + 1;
  c     = (isHor) ? (_idx % cols) + 1 : _idx / ((cnt / cols)+1) + 1;
    
  if ([self->index isValueSettable])
    [self->index setUnsignedIntValue:_idx inComponent:cmp];

  if ([self->row isValueSettable])
    [self->row setUnsignedIntValue:r inComponent:cmp];

  if ([self->col isValueSettable])
    [self->col setUnsignedIntValue:c inComponent:cmp];

  if ([self->item isValueSettable]) {
    if (_idx < cnt)
      [self->item setValue:[array objectAtIndex:_idx] inComponent:cmp];
    else {
      [cmp logWithFormat:@"WOTable: array did change, index is invalid."];
      [self->item setValue:nil inComponent:cmp];
    }
  }
}


- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSArray     *array;
  unsigned    cnt, i;

  cmp   = [_ctx component];
  array = [self->list valueInComponent:cmp];
  cnt   = [array count];

  [_ctx appendZeroElementIDComponent];

  [_ctx setObject:_WOTableContentString_ forKey:_WOTableContextMode_];

  for (i=0; i<cnt; i++) {
    _applyIndex(self, cmp, i);
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx incrementLastElementIDComponent];
  }

  [_ctx removeObjectForKey:_WOTableContextMode_];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  id          result = nil;

  cmp = [_ctx component];
  
  if ([self->list valueInComponent:cmp] != nil) {
    unsigned idx = [[_ctx currentElementID] intValue];
    NSString *s;
    
    [_ctx consumeElementID]; // consume index
    s = [[NSString alloc] initWithFormat:@"%i", idx];
    [_ctx appendElementIDComponent:s];
    [s release];
    _applyIndex(self, cmp, idx);
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *cmp   = nil;
  NSArray     *array = nil;
  BOOL        isHor  = NO; // is horizontal
  BOOL        drawTD = YES;
  unsigned    c, colCount; // column index
  unsigned    r, rowCount; // row    index
  unsigned    cnt;
  unsigned    ownTDCount = 0;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  cmp      = [_ctx component];
  colCount = [self->maxColumns unsignedIntValueInComponent:cmp];
  array    = [self->list valueInComponent:cmp];
  cnt      = [array count];
  isHor    = [self->horizontal boolValueInComponent:cmp];
  drawTD   = ![self->hasOwnTDs boolValueInComponent:cmp];
  if (!drawTD)
    ownTDCount = [self->hasOwnTDs intValueInComponent:cmp];
  
  colCount = (colCount < cnt) ? colCount : cnt;
  colCount = (colCount) ? colCount : 1;
  rowCount = ((cnt % colCount) > 0) ? (cnt / colCount) + 1 : (cnt / colCount);

  [_response appendContentString:@"<table "];
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentCharacter:'>'];

  if (!drawTD) {
    NSString *rowColor = [self->rowBackgroundColor stringValueInComponent:cmp];
    unsigned i;

    [_ctx setObject:_WOTableHeaderString_ forKey:_WOTableContextMode_];
    [_response appendContentString:@"<tr"];
    if (rowColor) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:rowColor];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    for (i = 0; i < colCount; i++) {
      [self->template appendToResponse:_response inContext:_ctx];
    }
    [_response appendContentString:@"</tr>"];
    [_ctx removeObjectForKey:_WOTableContextMode_];
  }

  if (!drawTD)
    [_ctx setObject:_WOTableContentString_ forKey:_WOTableContextMode_];

  for (r=0; r<rowCount; r++) {
    NSString *rowColor = [self->rowBackgroundColor stringValueInComponent:cmp];
    [_response appendContentString:@"<tr"];
    if (rowColor) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:rowColor];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    
    for (c=0; c<colCount; c++) {
      NSString *cColor = [self->cellBackgroundColor stringValueInComponent:cmp];
      NSString *align  = [self->cellAlign  stringValueInComponent:cmp];
      NSString *valign = [self->cellVAlign stringValueInComponent:cmp];
      NSString *width  = nil;
      unsigned i = (isHor) ? r*colCount+c : c*rowCount+r;
      
      if (drawTD) {
        [_response appendContentString:@"<td"];
        width = [[NSString alloc] initWithFormat:@"%d%%", (int)(100 / colCount)];
        if (width) {
          [_response appendContentString:@" width=\""];
          [_response appendContentString:width];
          [_response appendContentCharacter:'"'];
          [width release];
        }
        if (cColor) {
          [_response appendContentString:@" bgcolor=\""];
          [_response appendContentString:cColor];
          [_response appendContentCharacter:'"'];
        }
        if (align) {
          [_response appendContentString:@" align=\""];
          [_response appendContentString:align];
          [_response appendContentCharacter:'"'];
        }
        if (valign) {
          [_response appendContentString:@" valign=\""];
          [_response appendContentString:valign];
          [_response appendContentCharacter:'"'];
        }
        [_response appendContentCharacter:'>'];
      }
      if (i < cnt) {
        NSString *s;

        s = [[NSString alloc] initWithFormat:@"%i", i];
        [_ctx appendElementIDComponent:s];
        [s release];
        _applyIndex(self, cmp, i);
        [self->template appendToResponse:_response inContext:_ctx];
        [_ctx deleteLastElementIDComponent];
      }
      else if (ownTDCount > 0) {
        unsigned j;
        
        for (j = 0; j < ownTDCount; j++)
          [_response appendContentString:@"<td>&nbsp;</td>"];
      }
      else
        [_response appendContentString:@"&nbsp;"];

      if (drawTD)
        [_response appendContentString:@"</td>"];
    }
    [_response appendContentString:@"</tr>"];
  }
  if (!drawTD)
    [_ctx removeObjectForKey:_WOTableContextMode_];

  [_response appendContentString:@"</table>"];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:128];
  if (self->list)       [str appendFormat:@" list=%@",       self->list];
  if (self->item)       [str appendFormat:@" item=%@",       self->item];
  if (self->maxColumns) [str appendFormat:@" maxColumns=%@", self->maxColumns];
  if (self->index)      [str appendFormat:@" index=%@",      self->index];
  if (self->col)        [str appendFormat:@" col=%@",        self->col];
  if (self->row)        [str appendFormat:@" row=%@",        self->row];
  if (self->horizontal) [str appendFormat:@" horizontal=%@", self->horizontal];
  if (self->hasOwnTDs)  [str appendFormat:@" hasOwnTDs=%@",  self->hasOwnTDs];
  if (self->template)   [str appendFormat:@" template=%@",   self->template];
  return str;
}

@end /* WOTable */

@interface WOTableContextKey : WODynamicElement
{
  WOElement *template;
}
@end

@implementation WOTableContextKey

- (NSString *)_contextValue {
  return nil;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->template  = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  [super dealloc];
}

- (BOOL)doShow:(WOContext *)_ctx {
  NSString *key = [_ctx objectForKey:_WOTableContextMode_];

  if (key == nil)
    return NO;

  return [key isEqualToString:[self _contextValue]];
}

// ******************** responder ********************

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if (![self doShow:_ctx])
    return;

  [_ctx appendElementIDComponent:@"1"];
  [self->template takeValuesFromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  NSString *state;
  id result;

  if ((state = [[_ctx currentElementID] stringValue]) == nil)
    return nil;
  
  [_ctx consumeElementID]; // consume state-id (on or off)
  
  if (![state isEqualToString:@"1"])
    return nil;
  
  [_ctx appendElementIDComponent:state];
  result = [self->template invokeActionForRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (![self doShow:_ctx]) 
    return;

  [_ctx appendElementIDComponent:@"1"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

@end /* WOTableContextKey */

@interface WOTableHeader : WOTableContextKey
@end /* WOTableHeader */

@implementation WOTableHeader

- (NSString *)_contextValue {
  return _WOTableHeaderString_;
}

@end /* WOTableHeader */


@interface WOTableContent : WOTableContextKey
@end /* WOTableContent */

@implementation WOTableContent

- (NSString *)_contextValue {
  return _WOTableContentString_;
}

@end /* WOTableContent */
