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

#include <NGObjDOM/ODNodeRenderer.h>

/*
  Attributes:

    day    - int
    month  - int
    year   - int
    value  - string in format %Y-%m-%d
  
  Usage:
    <var:datefield value="fromDate"/><br/>
    <var:datefield value="toDate"/><br/>
*/

@interface ODR_bind_datefield : ODNodeRenderer
@end

#include "common.h"

@implementation ODR_bind_datefield

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  int d, m, y;
  NSString *s;
  
  [_ctx appendElementIDComponent:@"d"];
  d = [[_req formValueForKey:[_ctx elementID]] intValue];
  [_ctx deleteLastElementIDComponent];
  
  [_ctx appendElementIDComponent:@"m"];
  m = [[_req formValueForKey:[_ctx elementID]] intValue];
  [_ctx deleteLastElementIDComponent];
  
  [_ctx appendElementIDComponent:@"y"];
  y = [[_req formValueForKey:[_ctx elementID]] intValue];
  [_ctx deleteLastElementIDComponent];
  
  if (y < 100) y += 2000;
  
  if ([self isSettable:@"value" node:_node ctx:_ctx]) {
    s = [NSString stringWithFormat:@"%i-%02i-%02i", y, m, d];
    [self setString:s for:@"value" node:_node ctx:_ctx];
  }
  
  if ([self isSettable:@"day"   node:_node ctx:_ctx])
    [self setInt:d for:@"day"   node:_node ctx:_ctx];
  if ([self isSettable:@"month" node:_node ctx:_ctx])
    [self setInt:m for:@"month" node:_node ctx:_ctx];
  if ([self isSettable:@"year"  node:_node ctx:_ctx])
    [self setInt:y for:@"year"  node:_node ctx:_ctx];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  unsigned i;
  NSCalendarDate *date;
  NSString *s;
  NSString *d,*m,*y;
  
  d = [self stringFor:@"day"   node:_node ctx:_ctx];
  m = [self stringFor:@"month" node:_node ctx:_ctx];
  y = [self stringFor:@"year"  node:_node ctx:_ctx];
  
  date = [self valueFor:@"value" node:_node ctx:_ctx];
  
  if ([date isKindOfClass:[NSCalendarDate class]]) {
    s = [date descriptionWithCalendarFormat:@"%Y-%m-%s"];
    
    d = [NSString stringWithFormat:@"%i", [date dayOfMonth]];
    m = [NSString stringWithFormat:@"%i", [date monthOfYear]];
    y = [NSString stringWithFormat:@"%i", [date yearOfCommonEra]];
  }
  else {
    s = [date stringValue];
    date = nil;
    
    if ([s length] > 0) {
      NSArray  *comps;
      unsigned count;
    
      comps = [s componentsSeparatedByString:@"-"];
      count = [comps count];

      if (count > 0) y = [comps objectAtIndex:0];
      if (count > 1) m = [comps objectAtIndex:1];
      if (count > 2) d = [comps objectAtIndex:2];
    }
  }
  
  [_ctx appendElementIDComponent:@"d"];
  {
    [_response appendContentString:@"<select name=\""];
    [_response appendContentHTMLAttributeValue:[_ctx elementID]];
    [_response appendContentString:@"\" value=\""];
    [_response appendContentHTMLAttributeValue:d];
    [_response appendContentString:@"\">\n"];
    
    [_response appendContentString:@"<option value=\"\">-"];
    
    for (i = 1; i <= 31; i++) {
      s = [NSString stringWithFormat:@"%d", i];
      [_response appendContentString:@"<option value=\""];
      [_response appendContentString:s];
      if ((int)i == [d intValue])
        [_response appendContentString:@"\" selected=\"selected\" />"];
      else
        [_response appendContentString:@"\" />"];
      [_response appendContentString:s];
      
      /* XHTML */
    }
  
    [_response appendContentString:@"</select>"];
  }
  [_ctx deleteLastElementIDComponent];
  
  [_ctx appendElementIDComponent:@"m"];
  {
    static NSString *months[12] = {
      @"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
      @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"
    };
    [_response appendContentString:@"<select name=\""];
    [_response appendContentHTMLAttributeValue:[_ctx elementID]];
    [_response appendContentString:@"\" value=\""];
    [_response appendContentHTMLAttributeValue:m];
    [_response appendContentString:@"\">\n"];

    [_response appendContentString:@"<option value=\"\">-"];
    
    for (i = 1; i <= 12; i++) {
      s = [NSString stringWithFormat:@"%d", i];
      [_response appendContentString:@"<option value=\""];
      [_response appendContentString:s];
      if ((int)i == [m intValue])
        [_response appendContentString:@"\" selected=\"selected\" />"];
      else
        [_response appendContentString:@"\" />"];
      [_response appendContentString:months[i - 1]];
      
      /* XHTML */
    }
  
    [_response appendContentString:@"</select>"];
  }
  [_ctx deleteLastElementIDComponent];
  
  [_ctx appendElementIDComponent:@"y"];
  {
    [_response appendContentString:@"<select name=\""];
    [_response appendContentHTMLAttributeValue:[_ctx elementID]];
    [_response appendContentString:@"\" value=\""];
    [_response appendContentHTMLAttributeValue:y];
    [_response appendContentString:@"\">\n"];
    
    [_response appendContentString:@"<option value=\"\">-"];
    
    for (i = 2001; i <= 2010; i++) {
      s = [NSString stringWithFormat:@"%d", i];
      [_response appendContentString:@"<option value=\""];
      [_response appendContentString:s];
      if ((int)i == [y intValue])
        [_response appendContentString:@"\" selected=\"selected\" />"];
      else
        [_response appendContentString:@"\" />"];
      [_response appendContentString:s];
      
      /* XHTML */
    }
    
    [_response appendContentString:@"</select>"];
  }
  [_ctx deleteLastElementIDComponent];
}

@end /* ODR_bind_datefield */
