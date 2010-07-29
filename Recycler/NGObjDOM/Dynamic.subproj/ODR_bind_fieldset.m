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

#include <NGObjDOM/ODR_bind_fieldset.h>
#include "common.h"

@implementation ODR_bind_fieldset

- (void)_takeValuesFromField:(id)_field
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSMutableArray *fields;
  NSArray        *labels;
  
  fields  = [NSMutableArray arrayWithArray:(NSArray *)[_field childNodes]];
  labels  = ODRLookupQueryPath(_field, @"-label");

  [fields removeObjectsInArray:labels];
  
  [_ctx appendElementIDComponent:@"t"];
  [self takeValuesForChildNodes:labels fromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "t"
  
  [_ctx appendElementIDComponent:@"c"];
  [self takeValuesForChildNodes:fields fromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "c"
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSArray *fields;
  int     i, cnt;

  fields = ODRLookupQueryPath(_node, @"field");
  cnt    = [fields count];
  
  for (i = 0; i < cnt; i++) {
    id field;
    
    field = [fields objectAtIndex:i];
    
    [_ctx appendElementIDComponent:[NSString stringWithFormat:@"%i", i]];
    
    [self _takeValuesFromField:field fromRequest:_request inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete index
  }
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  id       result = nil;
  NSArray  *fields;
  NSString *idx;
  int      i;
    id             field;
    NSString       *section;
    NSArray        *labels;

  fields = ODRLookupQueryPath(_node, @"field");
  idx    = [_ctx currentElementID];
  i      = [idx intValue];

  if (i >= (int)[fields count]) {
    NSLog(@"%s: Warning! Index out of range.", __PRETTY_FUNCTION__);
    return nil;
  }

    field = [fields objectAtIndex:i];
    
    [_ctx appendElementIDComponent:idx];
    [_ctx consumeElementID];

    section = [_ctx currentElementID]; // "c" || "t"
    
    [_ctx appendElementIDComponent:section];
    [_ctx consumeElementID];

    labels = ODRLookupQueryPath(field, @"-label");

    if ([section isEqualToString:@"t"]) {
      result = [self invokeActionForChildNodes:labels
                     fromRequest:_request
                     inContext:_ctx];
    }
    else if ([section isEqualToString:@"c"]) {
      NSMutableArray *childs;
      
      childs = [NSMutableArray arrayWithArray:(NSArray *)[field childNodes]];
      [childs removeObjectsInArray:labels];
      
      result = [self invokeActionForChildNodes:childs
                     fromRequest:_request
                     inContext:_ctx];
    }
    
    [_ctx deleteLastElementIDComponent]; // section
    [_ctx deleteLastElementIDComponent]; // idx
    
  return result;
}

- (void)_appendField:(id)_field
  node:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSMutableArray *fields;
  NSArray        *labels;
  NSString       *label;
  NSString       *labelBgColor;
  NSString       *contentBgColor;
  NSString       *width;
  NSString       *fc, *ff, *fs;
  BOOL           hasFont;

  fc      = [self stringFor:@"fontcolor" node:_node ctx:_ctx];
  ff      = [self stringFor:@"fontface"  node:_node ctx:_ctx];
  fs      = [self stringFor:@"fontsize"  node:_node ctx:_ctx];
  hasFont = (fc !=nil || ff !=nil || fs != nil);

  label   = [self stringFor:@"label" node:_field ctx:_ctx];
  fields  = [NSMutableArray arrayWithArray:(NSArray *)[_field childNodes]];
  labels  = ODRLookupQueryPath(_field, @"-label");
  
  labelBgColor   = [self stringFor:@"labelcolor"   node:_node ctx:_ctx];
  contentBgColor = [self stringFor:@"contentcolor" node:_node ctx:_ctx];
  width          = [self stringFor:@"labelwidth"   node:_node ctx:_ctx];

  [fields removeObjectsInArray:labels];
  
  [_response appendContentString:@"<td valign=\"top\" align=\"right\""];
  if (labelBgColor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:labelBgColor];
    [_response appendContentCharacter:'"'];
  }
  if (width) {
    [_response appendContentString:@" width=\""];
    [_response appendContentString:width];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];
  [_ctx appendElementIDComponent:@"t"];

  if (hasFont)
    ODRAppendFont(_response, fc, ff, fs);
  
  [self appendChildNodes:labels toResponse:_response inContext:_ctx];
  if (label) {
    [_response appendContentString:label];
    [_response appendContentString:@":"];
  }
  
  if (hasFont)
    [_response appendContentString:@"</font>"];

  [_ctx deleteLastElementIDComponent]; // delete "t"
  [_response appendContentString:@"</td>"];
  
  [_response appendContentString:@"<td valign=\"top\""];
  if (contentBgColor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:contentBgColor];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentCharacter:'>'];
  
  [_ctx appendElementIDComponent:@"c"];
  [self appendChildNodes:fields toResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "c"
  [_response appendContentString:@"</td>"];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSArray *fields;
  int     i, cnt;

  fields = ODRLookupQueryPath(_node, @"field");
  cnt    = [fields count];
  
  [_response appendContentString:
             @"<table border=\"0\" width=\"100%\""
             @"cellspacing=\"0\" cellpadding=\"4\">"];
  
  for (i = 0; i < cnt; i++) {
    id field;

    field = [fields objectAtIndex:i];

    [_ctx appendElementIDComponent:[NSString stringWithFormat:@"%i", i]];
    
    [_response appendContentString:@"<tr>"];
    [self _appendField:field node:_node toResponse:_response inContext:_ctx];
    [_response appendContentString:@"</tr>"];

    [_ctx deleteLastElementIDComponent]; // delete index
  }
  [_response appendContentString:@"</table>"];
}

@end /* ODR_bind_fieldset */
