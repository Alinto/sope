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

#include <NGXmlRpc/NGAsyncResultProxy.h>
#include "common.h"

@implementation NGAsyncResultProxy

- (void)dealloc {
  [self->token  release];
  [self->target release];
  [self->result release];
  [super dealloc];
}

/* accessors */

- (BOOL)isReady {
  return self->isReady;
}
- (id)result {
  return self->result;
}

- (void)setTarget:(id)_target {
  ASSIGN(self->target, _target);
}
- (id)target {
  return self->target;
}
- (void)setAction:(SEL)_action {
  self->action = _action;
}
- (SEL)action {
  return self->action;
}

- (void)setToken:(NSString *)_token {
  ASSIGN(self->token, _token);
}
- (NSString *)token {
  return self->token;
}

- (void)becameReady {
  AUTORELEASE(self->keptObjects);
  self->keptObjects = nil;

  AUTORELEASE(RETAIN(self));
  [self->target performSelector:self->action withObject:self];
}

- (void)postResult:(id)_result {
  //[self logWithFormat:@"post result: %@", _result];
  self->isReady = YES;
  ASSIGN(self->result, _result);
  [self becameReady];
}
- (void)postFaultResult:(NSException *)_result {
  //[self logWithFormat:@"post fault result: %@", _result];
  ASSIGN(self->result, _result);
  self->isReady = YES;
  [self becameReady];
}

- (void)retainObject:(id)_object {
  if (self->keptObjects == nil)
    self->keptObjects = [[NSMutableArray alloc] initWithCapacity:4];
  [self->keptObjects addObject:_object];
}
- (void)releaseObject:(id)_object {
  [[_object retain] autorelease];
  [self->keptObjects removeObjectIdenticalTo:_object];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if ([self isReady])
    [ms appendFormat:@" ready=%@", self->result];
  else
    [ms appendString:@" pending"];
  
  [ms appendFormat:@" token=%@", self->token];
  [ms appendFormat:@" target=%@", self->target];
  
  if ([self->keptObjects isNotEmpty])
    [ms appendFormat:@" keeping=%@", self->keptObjects];
  
  [ms appendString:@">"];
  
  return ms;
}

@end /* NGAsyncResultProxy */
