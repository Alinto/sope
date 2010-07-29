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

#include "SxComponentException.h"
#include "SxBasicAuthCredentials.h"
#include "SxComponentInvocation.h"
#include "common.h"

@implementation NSException(SxComponentExceptionTyping)

- (BOOL)isCredentialsRequiredException {
  return NO;
}

@end /* NSException(SxComponentExceptionTyping) */

@implementation SxComponentException
@end /* SxComponentException */

@implementation SxAuthException

- (id)init {
  return [self initWithName:NSStringFromClass([self class])
               reason:nil
               userInfo:nil];
}

- (void)dealloc {
  RELEASE(self->invocation);
  RELEASE(self->credentials);
  [super dealloc];
}

/* accessors */

- (BOOL)isCredentialsRequiredException {
  return YES;
}

- (void)setCredentials:(id)_credentials {
  ASSIGN(self->credentials, _credentials);
}
- (id)credentials {
  return self->credentials;
}

- (void)setInvocation:(SxComponentInvocation *)_invocation {
  ASSIGN(self->invocation, _invocation);
}
- (SxComponentInvocation *)invocation {
  return self->invocation;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id t;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]: name=%@",
        self, NSStringFromClass([self class]),
        [self name]];
  
  if ([self isCredentialsRequiredException])
    [ms appendString:@" cred-required"];

  if ((t = [self credentials]))
    [ms appendFormat:@" creds=%@", t];
  
  if ((t = [self invocation]))
    [ms appendFormat:@" inv=%@", t];
  
  [ms appendString:@">"];
  
  return ms;
}

@end /* SxAuthException */

@implementation SxMissingCredentialsException
@end /* SxMissingCredentialsException */

@implementation SxInvalidCredentialsException
@end /* SxInvalidCredentialsException */
