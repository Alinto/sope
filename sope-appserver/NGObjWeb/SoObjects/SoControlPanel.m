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

#include "SoControlPanel.h"
#include "SoClassSecurityInfo.h"
#include "SoProductRegistry.h"
#include "SoObject.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation SoControlPanel

+ (int)version {
  return 1;
}

- (id)handleQueryWithUnboundKey:(NSString *)_key {
  return [self lookupName:_key 
	       inContext:[[WOApplication application] context]
	       acquire:YES];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_ac {
  if ([_key isEqualToString:@"Products"])
    return [SoProductRegistry sharedProductRegistry];
  
  return [super lookupName:_key inContext:_ctx acquire:_ac];
}

- (NSArray *)toOneRelationshipKeys {
  NSArray *a;
  
  if ((a = [super toOneRelationshipKeys])) {
    return ([a containsObject:@"Products"])
      ? a : [a arrayByAddingObject:@"Products"];
  }
  else
    return [NSArray arrayWithObject:@"Products"];
}

- (NSArray *)manageMenuChildNames {
  return nil;
}

/* if accessed directly ... */

- (void)appendToResponse:(WOResponse *)_response inContext:(id)_ctx {
  // should invoke GETAction in the SMI ...
  [_response appendContentString:@"<h3>SOPE Control Panel</h3>"];
  [_response appendContentString:
	       @"<li><a href=\"Products/\">Products</a></li>"];
}

@end /* SoControlPanel */
