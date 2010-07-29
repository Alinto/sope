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

#include <NGObjWeb/WODirectActionRequestHandler.h>
#include <NGObjWeb/WODirectAction.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOApplication.h>
#include "SoObject.h"
#include "common.h"

@implementation WODirectActionRequestHandler(Pub)

- (id)parentObject {
  return [WOApplication application];
}

- (BOOL)allowDirectActionClass:(Class)_clazz {
#if 0
#warning to be completed ...
    if (![clazz isSubclassOfClass:[WODirectAction class]])
      clazz = Nil;
#endif
  return YES;
}

- (id)lookupName:(NSString *)_name inContext:(id)_ctx acquire:(BOOL)_ac {
  Class clazz;
  BOOL  lookupInAction = NO;
  
  /* check whether name is a direct-action class */
  if ((clazz = NSClassFromString(_name))) {
    if (![self allowDirectActionClass:clazz])
      clazz = Nil;
  }
  else {
    /* automatically use DirectAction class */
    lookupInAction = YES;
    clazz = NSClassFromString(@"DirectAction");
  }
  
  /* found a class, construct direct action */
  if (clazz) {
    WODirectAction *actionObject;
    WOContext      *ctx;
    
    ctx = _ctx != nil ? _ctx : (id)[[WOApplication application] context];
    
    if ((actionObject = [[clazz alloc] initWithContext:ctx]) == nil) {
      /* failed to create object */
      return nil;
    }
    actionObject = [actionObject autorelease];
    
    return lookupInAction
      ? [actionObject lookupName:_name inContext:ctx acquire:_ac]
      : (id)actionObject;
  }
  
  return [super lookupName:_name inContext:_ctx acquire:_ac];
}

@end /* WODirectActionRequestHandler(Pub) */
