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

#include "NSException+HTTP.h"
#include "common.h"

@implementation NSException(HTTP)

+ (id)exceptionWithHTTPStatus:(unsigned short)_status {
  return [self exceptionWithHTTPStatus:_status reason:nil];
}

+ (NSString *)exceptionNameForHTTPStatus:(unsigned short)_status {
  switch (_status) {
    case 401: return @"AuthRequired";
    case 403: return @"Forbidden";
    case 404: return @"NotFound";
    default:  return [NSString stringWithFormat:@"HTTP %i", _status];
  }
}
+ (NSString *)exceptionReasonForHTTPStatus:(unsigned short)_status {
  switch (_status) {
    case 401: return @"authentication is required for access to the object!";
    case 403: return @"you are not allowed to access the object!";
    case 404: return @"the requested object could not be found!";
    default:  return @"reason for HTTP error unknown";
  }
}

+ (id)exceptionWithHTTPStatus:(unsigned short)_status reason:(NSString *)_r {
  return [[[SoHTTPException alloc] 
	    initWithHTTPStatus:_status reason:_r] autorelease];
}
- (id)initWithHTTPStatus:(unsigned short)_status reason:(NSString *)_r {
  NSDictionary *ui;
  NSString *errorName;
  NSString *lReason;

  ui = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_status]
		     forKey:@"http-status"];
  
  errorName = [[self class] exceptionNameForHTTPStatus:_status];
  lReason   = _r ? _r : [[self class] exceptionReasonForHTTPStatus:_status];
  
  return [self initWithName:errorName reason:lReason userInfo:ui];
}

- (unsigned short)httpStatus {
  return [[[self userInfo] objectForKey:@"http-status"] intValue];
}

- (void)detachFromContainer {
  /* to be usable in OFS */
}

/* KVC */

- (id)handleQueryWithUnboundKey:(NSString *)_key {
  // TODO: is this considered a hack ?
  return nil;
}

@end /* NSException(HTTP) */

@implementation SoHTTPException

- (id)initWithHTTPStatus:(unsigned short)_status reason:(NSString *)_r {
  NSString *errorName;
  NSString *lReason;
  
  errorName = [[self class] exceptionNameForHTTPStatus:_status];
  lReason   = _r ? _r : [[self class] exceptionReasonForHTTPStatus:_status];
  
  if (([self initWithName:errorName reason:lReason userInfo:nil])) {
    self->status = _status;
  }
  return self;
}

- (unsigned short)httpStatus {
  return self->status;
}

@end /* SoHTTPException */
