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

#include "SoSecurityException.h"
#include "SoSecurityManager.h"
#include "common.h"

@implementation SoSecurityException

+ (id)securityExceptionOnObject:(id)_o 
  withAuthenticator:(id)_a 
  andManager:(id)_m 
{
  return [[[self alloc] 
	    initWithObject:_o authenticator:_a manager:_m] autorelease];
}
- (id)initWithObject:(id)_object authenticator:(id)_auth manager:(id)_manager {
  NSString *n, *r;
  
  if ((n = [self name]) == nil)
    n = NSStringFromClass([self class]);
  if ((r = [self reason]) == nil)
    r = @"generic security exception";
  
  if ((self = [super initWithName:n reason:r userInfo:nil])) {
    self->object          = [_object  retain];
    self->authenticator   = [_auth    retain];
    self->securityManager = [_manager retain];
  }
  return self;
}

- (void)dealloc {
  [self->object          release];
  [self->securityManager release];
  [self->authenticator   release];
  [super dealloc];
}

/* accessors */

- (SoSecurityManager *)securityManager {
  return self->securityManager;
}
- (id)authenticator {
  return self->authenticator;
}
- (id)object {
  return self->object;
}

@end /* SoSecurityManager */

@implementation SoAuthRequiredException

- (unsigned short)httpStatus {
  return 401;
}

- (NSString *)name {
  return @"SoAuthRequired";
}
- (NSString *)reason {
  return @"authentication required";
}

@end /* SoAuthRequiredException */

@implementation SoAccessDeniedException

- (unsigned short)httpStatus {
  return 403;
}

@end /* SoAccessDeniedException */
