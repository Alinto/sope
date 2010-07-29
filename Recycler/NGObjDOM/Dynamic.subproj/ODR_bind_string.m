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
  
    value      - value to be generated
    nilValue   - value to be generated if value is nil
    dateformat - a date formatting spec
    numberformat
    escapehtml - bool (default: true)
    insertbr   - bool (default: false)
  
  Usage:
    <var:string value="name"/>
*/

@interface ODR_bind_string : ODNodeRenderer
@end

#include "common.h"
#import <Foundation/NSDateFormatter.h>

@implementation ODR_bind_string

- (NSFormatter *)_formatterForNode:(id)_node inContext:(WOContext *)_ctx {
  NSFormatter *formatter;
  NSString    *fmt;
  
  if ((fmt = [self stringFor:@"dateformat" node:_node ctx:_ctx])) {
    formatter = [[NSDateFormatter alloc]
                                  initWithDateFormat:fmt
                                  allowNaturalLanguage:NO];
    AUTORELEASE(formatter);
  }
  else if ((fmt = [self stringFor:@"numberformat" node:_node ctx:_ctx])) {
    formatter = [[NSNumberFormatter alloc] init];
    AUTORELEASE(formatter);
    [(NSNumberFormatter *)formatter setFormat:fmt];
  }
  else
    formatter = nil;

  return formatter;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id          value;
  NSString    *string = nil;
  BOOL        insertBR;
  SEL         selector;
  NSFormatter *formatter;
  
  if ((value = [self valueFor:@"value" node:_node ctx:_ctx]) == nil)
    value = [self valueFor:@"nilValue" node:_node ctx:_ctx];
  
  formatter = [self _formatterForNode:_node inContext:_ctx];
  
  string = formatter
    ? [formatter stringForObjectValue:value]
    : [value stringValue];
  
  if (string == nil)
    return;

  string = [string stringValue];
  
  insertBR = [self boolFor:@"insertbr" node:_node ctx:_ctx];
  
  selector = ![self hasAttribute:@"escapehtml" node:_node ctx:_ctx]
    ? @selector(appendContentHTMLString:)
    : ([self boolFor:@"escapehtml" node:_node ctx:_ctx]
       ? @selector(appendContentHTMLString:)
       : @selector(appendContentString:));
  
  if (!insertBR) {
    [_response performSelector:selector withObject:string];
  }
  else {
    NSArray *lines;
    unsigned i, count;
    
    lines = [string componentsSeparatedByString:@"\n"];
    count = [lines count];
    
    for (i = 0; i < count; i++) {
      NSString *line = [lines objectAtIndex:i];
      
      if (i != 0)
        [_response appendContentString:@"<br />"];
      
      [_response performSelector:selector withObject:line];
    }
  }
}

@end /* ODR_bind_string */
