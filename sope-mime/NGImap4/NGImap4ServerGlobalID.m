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

#include "NGImap4ServerGlobalID.h"
#include "imCommon.h"

@implementation NGImap4ServerGlobalID

+ (id)imap4ServerGlobalIDForHostname:(NSString *)_host port:(int)_port
  login:(NSString *)_login
{
  NGImap4ServerGlobalID *gid;

  gid = [[self alloc] initWithHostname:_host port:_port login:_login];
  return [gid autorelease];
}

- (id)initWithHostname:(NSString *)_host port:(int)_p login:(NSString *)_l {
  if ((self = [super init])) {
    self->hostName = [_host copy];
    self->login    = [_l    copy];
    self->port     = _p;
  }
  return self;
}
- (id)init {
  return [self initWithHostname:nil port:0 login:nil];
}

- (void)dealloc {
  [self->hostName release];
  [self->login    release];
  [super dealloc];
}

/* accessors */

- (NSString *)hostName {
  return self->hostName;
}
- (NSString *)login {
  return self->login;
}
- (int)port {
  return self->port;
}

/* comparison */

- (unsigned)hash {
  return [self->login hash];
}

- (BOOL)isEqualToImap4ServerGlobalID:(NGImap4ServerGlobalID *)_other {
  if (_other == nil)
    return NO;
  if (self == _other)
    return YES;
  
  if (self->login != _other->login) {
    if (![self->login isEqualToString:_other->login])
      return NO;
  }
  if (self->hostName != _other->hostName) {
    if (![self->hostName isEqualToString:_other->hostName])
      return NO;
  }
  if (self->port != _other->port)
    return NO;
  
  return YES;
}

- (BOOL)isEqual:(id)_otherObject {
  if (_otherObject == self)
    return YES;
  if (![_otherObject isKindOfClass:[self class]])
    return NO;
  
  return [self isEqualToImap4ServerGlobalID:_otherObject];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* support for some older code expecting only EO global IDs */

- (NSString *)entityName {
  return @"NGImap4Client";
}

@end /* NGImap4ServerGlobalID */
