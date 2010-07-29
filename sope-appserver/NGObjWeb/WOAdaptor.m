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
// $id: WOAdaptor.m,v 1.18 2000/10/11 10:06:15 helge Exp $

#include <NGObjWeb/WOAdaptor.h>
#include "common.h"

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation WOAdaptor

+ (int)version {
  return 1;
}

- (id)initWithName:(NSString *)_name arguments:(NSDictionary *)_args
  application:(WOCoreApplication *)_application
{
  if ((self = [super init])) {
    self->application = _application;
    self->name        = [_name copyWithZone:[self zone]];
  }
  return self;
}

- (void)dealloc {
  self->application = nil;
  [self->name release];
  [super dealloc];
}

- (void)registerForEvents {
  [self subclassResponsibility:_cmd];
}
- (void)unregisterForEvents {
  [self subclassResponsibility:_cmd];
}

@end /* WOAdaptor */
