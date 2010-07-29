/*
  Copyright (C) 2005 Helge Hess

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

#include "WEPrototypeScript.h"
#include "common.h"

@implementation WEPrototypeScript

static NSString *WEPrototypeScriptKey = @"WEPrototypeScriptKey";

/* generating response */

+ (BOOL)wasDeliveredInContext:(WOContext *)_ctx {
  return [[_ctx objectForKey:WEPrototypeScriptKey] boolValue];
}

+ (void)markDeliveredInContext:(WOContext *)_ctx {
  [_ctx setObject:@"YES" forKey:WEPrototypeScriptKey];
}

+ (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *url;

  if ([_ctx isRenderingDisabled]) return;
  if ([self wasDeliveredInContext:_ctx]) return;
  
  url = [_ctx directActionURLForActionNamed:
		@"WEPrototypeScriptAction/default.js"
	      queryDictionary:nil];
  
  [_response appendContentString:@"<script type=\"text/javascript\" src=\""];
  [_response appendContentHTMLAttributeValue:url];
  [_response appendContentString:@"\"> </script>"];
  
  [self markDeliveredInContext:_ctx];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  [[self class] appendToResponse:_response inContext:_ctx];
}

@end /* WEPrototypeScript */
