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

#include "WOComponentFault.h"
#include "WOComponent+private.h"
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"

@implementation WOComponentFault

+ (int)version {
  return 2;
}

- (id)initWithResourceManager:(WOResourceManager *)_rm
  pageName:(NSString *)_name
  languages:(NSArray *)_langs
  bindings:(NSDictionary *)_bindings
{
  NSZone *z = [self zone];
  self->resourceManager = RETAIN(_rm);
  self->pageName        = [_name     copyWithZone:z];
  self->languages       = [_langs    copyWithZone:z];
  self->bindings        = [_bindings copyWithZone:z];
  
  [[NSNotificationCenter defaultCenter]
                         addObserver:self
                         selector:@selector(_contextWillDealloc:)
                         name:@"WOContextWillDeallocate" object:nil];
  
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(self->bindings);
  RELEASE(self->resourceManager);
  RELEASE(self->pageName);
  RELEASE(self->languages);
  [super dealloc];
}

/* ctx dealloc */

- (void)_contextWillDealloc:(NSNotification *)_notification {
#if DEBUG
  NSAssert(_notification, @"missing valid notification arg ...");
#endif
  
  if (self->ctx == nil)
    /* component isn't interested in context anyway ... */
    return;
  if (![[self->ctx contextID] isEqualToString:[_notification object]])
    /* not the component's context ... */
    return;
  
  self->ctx = nil;
}

/* cached awake & sleep */

- (void)ensureAwakeInContext:(WOContext *)_ctx {
  self->ctx = _ctx;
}
- (void)_awakeWithContext:(WOContext *)_ctx {
  [self ensureAwakeInContext:_ctx];
}
- (void)_sleepWithContext:(WOContext *)_ctx {
  self->ctx = nil;
}

/* resolve */

- (WOComponent *)resolveWithParent:(WOComponent *)_parent {
  WOComponent *c;
  WOResourceManager *rm;
  
#if DEBUG && 0
  [self logWithFormat:@"resolving fault for component %@", self->pageName];
#endif

  if ((rm = self->resourceManager))
    ;
  else if ((rm = [_parent resourceManager]))
    ;
  else
    rm = [[WOApplication application] resourceManager];
  
  c = [rm pageWithName:self->pageName languages:self->languages];
  //[self logWithFormat:@"  rm:   %@", rm];
  //[self logWithFormat:@"  c:    %@", c];
  
  [c setBindings:self->bindings];
  [c setParent:_parent];
  if (self->ctx) [c _awakeWithContext:self->ctx];
  
  if (c == NULL) {
    [self logWithFormat:@"could not resolve fault for component: %@",
            self->pageName];
    [self logWithFormat:@"  resource-manager: %@", rm];
    [self logWithFormat:@"  parent:           %@", _parent];
  }
  
  return c;
}

- (void)setParent:(id)_parent {
  /*
    Not attached to a parent, this is called by WOComponent -dealloc on
    each child (which can be a fault).
  */
}

- (BOOL)isComponentFault {
  return YES;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->pageName];
  [_coder encodeObject:self->languages];
  [_coder encodeObject:self->bindings];
}
- (id)initWithCoder:(NSCoder *)_decoder {
  if ((self = [super init])) {
    self->pageName  = [[_decoder decodeObject] copy];
    self->languages = [[_decoder decodeObject] retain];
    self->bindings  = [[_decoder decodeObject] retain];
  }
  return self;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

@end /* WOComponentFault */

@implementation WOComponent(WOComponentFault)

- (BOOL)isComponentFault {
  return NO;
}

@end /* WOComponent(WOComponentFault) */
