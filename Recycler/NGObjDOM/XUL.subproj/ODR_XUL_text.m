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

@interface ODR_XUL_text : ODRDynamicXULTag
@end

#include <NGObjDOM/ODNamespaces.h>
#include "common.h"

@implementation ODR_XUL_text

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *string;

  string = [self stringFor:@"value" node:_node ctx:_ctx];
  
  if (![string isKindOfClass:[NSString class]])
    string = [string stringValue];

  if (string) {
#if DEBUG
    NSAssert2([string isKindOfClass:[NSString class]],
              @"got non-string -stringValue... %@<%@>",
              string, NSStringFromClass([string class]));
#endif
    [_response appendContentHTMLString:string];
  }
  
  if ([_node hasChildNodes]) {
    [self appendChildNodes:[_node childNodes]
          toResponse:_response
          inContext:_ctx];
  }
}

@end /* ODR_XUL_text */
