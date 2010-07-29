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

#include "ODRDynamicXULTag.h"

@interface ODR_XUL_grid : ODRDynamicXULTag
@end

#include <NGObjDOM/ODNamespaces.h>
#include "common.h"

@implementation ODR_XUL_grid


- (void)appendRows:(NSArray *)_rows
           columns:(NSArray *)_columns
       doRowsFirst:(BOOL)_doRowsFirst
        toResponse:(WOResponse *)_response
         inContext:(id)_context
{
  int i, j, cnt, cnt2;

  for (i = 0, cnt = [_rows count]; i < cnt; i++) {
    id row;

    row = [_rows objectAtIndex:i];
    if (![[row nodeName] isEqualToString:@"row"])
      continue;
      
    NSLog(@"__row is %@", row);
    [_response appendContentString:@"<tr>"];
    for (j = 0, cnt2 = [_columns count]; j < cnt; j++) {
      id col;

      col = [_columns objectAtIndex:i];
      if (![[col nodeName] isEqualToString:@"column"])
        continue;
        
      [_response appendContentString:@"<td>"];
      [self appendChildNodes:[(id)((_doRowsFirst) ? row : col) childNodes]
            toResponse:_response
            inContext:_context];
      [self appendChildNodes:[(id)((_doRowsFirst) ? col : row) childNodes]
            toResponse:_response
            inContext:_context];
      [_response appendContentString:@"</td>"];
    }
    [_response appendContentString:@"</tr>"];
  }
}


- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{

  NSArray  *childNodes;
  BOOL     doRowsFirst = NO;
  id       rows     = nil;
  id       columns  = nil;
  unsigned colCount = 0;
  unsigned rowCount = 0;
  unsigned i, cnt;

  if (![_domNode hasChildNodes])
    return;

  childNodes = (NSArray *)[_domNode childNodes];

  // get child rows and columns
  for (i = 0, cnt = [childNodes count]; i < cnt; i++) {
    id child;
    
    child = [childNodes objectAtIndex:i];
    if ([[child nodeName] isEqualToString:@"columns"]) {
      doRowsFirst = (rowCount == 0) ? NO : doRowsFirst;
      columns = child;
      colCount++;
    }
    else if ([[child nodeName] isEqualToString:@"rows"]) {
      doRowsFirst = (colCount == 0) ? YES : doRowsFirst;
      rows = child;
      rowCount++;
    }
  }

  if (colCount != 1 || rowCount != 1) {
    NSLog(@"Warning: wrong row or column count");
    return;
  }
  
  [_response appendContentString:@"<table border=\"1\">"];
  [self appendRows:(NSArray *)[rows childNodes]
        columns:(NSArray *)[columns childNodes]
        doRowsFirst:doRowsFirst
        toResponse:_response
        inContext:_context];
  [_response appendContentString:@"</table>"];
}

@end /* ODR_XUL_grid */
