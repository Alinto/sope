/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include <NGObjWeb/WODirectAction.h>
#include "WOContext+SoObjects.h"
#include "SoObject.h"
#include "common.h"

/*
  WODirectActionPubInvocation
  
  This invocation is used if you have a direct action in the lookup path, this
  can be configured by setting a WODirectAction subclass as a 'slot' of a
  class.
*/

@interface WODirectActionPubInvocation : NSObject
{
@public
  WODirectAction *parent;
  NSString *daName;
}
@end

@implementation WODirectAction(SoObjectRequestHandler)

- (id)clientObject {
  return [[(id)self context] clientObject];
}

- (id)lookupName:(NSString *)_name inContext:(id)_ctx acquire:(BOOL)_flag {
  WODirectActionPubInvocation *inv;
  NSString *daName;
  SEL sel;
  
  daName = [_name stringByAppendingString:@"Action"];
  sel    = daName ? NSSelectorFromString(daName) : NULL;
  
  if (![self respondsToSelector:sel])
    return [super lookupName:_name inContext:_ctx acquire:_flag];
    
  inv = [[WODirectActionPubInvocation alloc] init];
  inv->daName = [_name copy];
  inv->parent = [self retain];
  return [inv autorelease];
}

@end /* WODirectAction(SoObjectRequestHandler) */

@implementation WODirectActionPubInvocation

- (void)dealloc {
  [self->daName release];
  [self->parent release];
  [super dealloc];
}

- (id)parentObject {
  return self->parent;
}

- (BOOL)isCallable {
  return YES;
}
- (id)callOnObject:(id)_object inContext:(id)_ctx {
  return [(_object != nil)
	   ? _object 
	   : (id)self->parent performActionNamed:self->daName];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" action=%@", self->daName];
  [ms appendFormat:@" class=%@", NSStringFromClass([self->parent class])];
  [ms appendString:@">"];
  return ms;
}

@end /* WODirectActionPubInvocation */
