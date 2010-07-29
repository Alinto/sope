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

@interface WOCheckBoxMatrix : WODynamicElement
{
  // WODynamicElement: extraAttributes (are appended at the main table)
  // WODynamicElement: otherTagString
@protected
  WOAssociation *list;       // array of objects to iterate through
  WOAssociation *item;       // current item in the array
  WOAssociation *selections; // selected objects
  WOAssociation *maxColumns; // number of columns
  
  /* non WO attribute */
  WOAssociation *index;      // current index
  WOAssociation *col;        // current column (is updated with each iteration)
  WOAssociation *row;        // current row    (is updated with each iteration)

  WOAssociation *cellAlign;  // current cell align
  WOAssociation *cellVAlign; // current cell valign
  WOAssociation *rowBackgroundColor;  // current row background color;
  WOAssociation *cellBackgroundColor; // current cell background color;
  WOAssociation *horizontal;   // order items horizontal (default = NO)

  WOElement     *template;
}
@end

#include "common.h"

@implementation WOCheckBoxMatrix

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
    return [[NSString alloc] initWithFormat:@"%i", i];
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->list       = WOExtGetProperty(_config, @"list");
    self->item       = WOExtGetProperty(_config, @"item");
    self->selections = WOExtGetProperty(_config, @"selections");
    self->maxColumns = WOExtGetProperty(_config, @"maxColumns");
    
    self->index      = WOExtGetProperty(_config, @"index");
    self->col        = WOExtGetProperty(_config, @"col");
    self->row        = WOExtGetProperty(_config, @"row");
    self->horizontal = WOExtGetProperty(_config, @"horizontal");

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
  RELEASE(self->template);
  
  RELEASE(self->list);
  RELEASE(self->item);
  RELEASE(self->maxColumns);
  RELEASE(self->selections);
  
  RELEASE(self->index);
  RELEASE(self->col);
  RELEASE(self->row);
  RELEASE(self->horizontal);

  RELEASE(self->cellAlign);
  RELEASE(self->cellVAlign);
  RELEASE(self->rowBackgroundColor);
  RELEASE(self->cellBackgroundColor);
  [super dealloc];
}

/* request handling */

static inline
void _applyIndex(WOCheckBoxMatrix *self, WOComponent *cmp, unsigned _idx)
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
      [cmp logWithFormat:
           @"WOCheckBoxMatrix: array did change, index is invalid."];
      [self->item setValue:nil inComponent:cmp];
    }
  }
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSArray     *array;
  NSArray     *selArray = nil;
  unsigned    cnt, i;

  cmp   = [_ctx component];
  array = [self->list valueInComponent:cmp];
  cnt   = [array count];

  if (cnt) {
    NSMutableArray *newSelection = nil;

    if (self->selections)
        newSelection = [[NSMutableArray alloc] initWithCapacity:cnt];
  
    [_ctx appendZeroElementIDComponent];
    for (i = 0; i < cnt; i++) {
      id formValue = nil;
      id obj       = nil;
      
      _applyIndex(self, cmp, i);
      [self->template takeValuesFromRequest:_req inContext:_ctx];

      if ((formValue = [_req formValueForKey:[_ctx elementID]])) {
        NSString *s;

        s = retStrForInt(i);
        if ([formValue isEqualToString:s]) {
          if ((obj = [self->item valueInComponent:cmp]) && (newSelection))
            [newSelection addObject:obj];
        }
        [s release];
      }
      [_ctx incrementLastElementIDComponent];
    }
    [_ctx deleteLastElementIDComponent];

    if (self->selections) {
      selArray = [newSelection copy];
      [newSelection release];
    }
  }
  else
    selArray = [[NSArray alloc] init];

  if ([self->selections isValueSettable])
    [self->selections setValue:selArray inComponent:cmp];

  [selArray release];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  id          result = nil;
  unsigned    idx;
  NSString    *s;

  cmp = [_ctx component];
  if ([self->list valueInComponent:cmp] == nil)
    return nil;
  
  idx = [[_ctx currentElementID] intValue];
  [_ctx consumeElementID]; // consume index
  s = retStrForInt(idx);
  [_ctx appendElementIDComponent:s];
  [s release];
  _applyIndex(self, cmp, idx);
  result = [self->template invokeActionForRequest:_req inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  return result;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSArray     *array;
  NSArray     *selArray;
  BOOL        isHor;       // is horizontal
  unsigned    c, colCount; // column index
  unsigned    r, rowCount; // row    index
  unsigned    cnt;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  cmp      = [_ctx component];
  colCount = [self->maxColumns unsignedIntValueInComponent:cmp];
  array    = [self->list valueInComponent:cmp];
  cnt      = [array count];
  isHor    = [self->horizontal boolValueInComponent:cmp];
  selArray = [self->selections valueInComponent:cmp];

  colCount = (colCount) ? colCount : 1;
  rowCount = ((cnt % colCount) > 0) ? (cnt / colCount) + 1 : (cnt / colCount);

  [_response appendContentString:@"<table "];
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentCharacter:'>'];

  for (r = 0; r < rowCount; r++) {
    NSString *rowColor;
    
    rowColor = [self->rowBackgroundColor stringValueInComponent:cmp];
    [_response appendContentString:@"<tr"];
    if (rowColor) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:rowColor];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    
    for (c = 0; c < colCount; c++) {
      NSString *cColor, *align, *valign;
      unsigned i;
      
      cColor = [self->cellBackgroundColor stringValueInComponent:cmp];
      align  = [self->cellAlign  stringValueInComponent:cmp];
      valign = [self->cellVAlign stringValueInComponent:cmp];
      i = (isHor) ? (r * colCount + c) : (c * rowCount + r);
      
      [_response appendContentString:@"<td"];
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
      
      if (i < cnt) {
        NSString *s;
        id obj;
        
        s = retStrForInt(i);
        [_ctx appendElementIDComponent:s];
        [s release];
        _applyIndex(self, cmp, i);
        obj = [self->item valueInComponent:cmp];

        // append check box
        [_response appendContentString:@"<input type=\"checkbox\" name=\""];
        [_response appendContentHTMLAttributeValue:[_ctx elementID]];
        [_response appendContentString:@"\" value=\""];
        s = retStrForInt(i);
        [_response appendContentString:s];
        [s release];
        [_response appendContentCharacter:'"'];
	
	// TODO: need a ctx flag for empty attributes
        if ([selArray containsObject:obj])
         [_response appendContentString:@" checked=\"checked\""];
        
	[_response appendContentString:
		     (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];
	
        /* append template */
        [self->template appendToResponse:_response inContext:_ctx];
        [_ctx deleteLastElementIDComponent];
      }
      else
        [_response appendContentString:@"&nbsp;"]; // TODO: XML/XHTML?
      [_response appendContentString:@"</td>"];
    }
    [_response appendContentString:@"</tr>"];
  }
  [_response appendContentString:@"</table>"];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:128];
  if (self->list)       [str appendFormat:@" list=%@",       self->list];
  if (self->item)       [str appendFormat:@" item=%@",       self->item];
  if (self->maxColumns) [str appendFormat:@" maxColumns=%@", self->maxColumns];
  if (self->selections) [str appendFormat:@" selections=%@", self->selections];
  if (self->index)      [str appendFormat:@" index=%@",      self->index];
  if (self->col)        [str appendFormat:@" col=%@",        self->col];
  if (self->row)        [str appendFormat:@" row=%@",        self->row];
  if (self->horizontal) [str appendFormat:@" horizontal=%@", self->horizontal];
  if (self->template)   [str appendFormat:@" template=%@",   self->template];

  return str;
}

@end /* WOCheckBoxMatrix */
