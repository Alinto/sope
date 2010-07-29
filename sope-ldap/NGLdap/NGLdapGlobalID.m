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

#include "NGLdapGlobalID.h"
#include "NSString+DN.h"
#import <EOControl/EOControl.h>
#include "common.h"

@implementation NGLdapGlobalID

- (id)initWithHost:(NSString *)_host port:(int)_port dn:(NSString *)_dn {
  self->host = [_host copy];
  self->port = _port;
  self->dn   = [[[_dn dnComponents] componentsJoinedByString:@","] copy];
  return self;
}

- (void)dealloc {
  [self->host release];
  [self->dn   release];
  [super dealloc];
}

/* accessors */

- (NSString *)host {
  return self->host;
}
- (NSString *)dn {
  return self->dn;
}
- (int)port {
  return self->port;
}

/* equality */

- (unsigned)hash {
  return [self->dn hash] + [self->host hash];
}

- (BOOL)isEqual:(id)_other {
  NGLdapGlobalID *ooid;
  
  if ([_other class] != [self class])
    return NO;

  ooid = _other;

  if ((ooid->dn == self->dn) &&
      (ooid->host == self->host) &&
      (ooid->port == self->port))
    return YES;

  if (![ooid->dn isEqualToString:self->dn])
    return NO;
  if (ooid->port != self->port)
    return NO;
  if (![ooid->host isEqualToString:self->host])
    return NO;

  return YES;
}

/* description */

- (NSString *)stringValue {
  return [NSString stringWithFormat:@"%@:%i/%@",
                     self->host, self->port, self->dn];
}

- (NSString *)description {
  NSMutableString *s;
  NSString *d;
  
  s = [[NSMutableString alloc] init];
  [s appendFormat:@"<0x%p[%@]: ", self, NSStringFromClass([self class])];
  [s appendFormat:@" host=%@", self->host];
  [s appendFormat:@" port=%i", self->port];
  [s appendFormat:@" dn=%@", self->dn];
  [s appendString:@">"];

  d = [s copy];
  [s release];
  return [d autorelease];
}

@end /* NGLdapGlobalID */
