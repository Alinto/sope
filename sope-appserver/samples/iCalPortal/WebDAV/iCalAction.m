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

#include "iCalAction.h"
#include "iCalPortalDatabase.h"
#include "iCalPortalUser.h"
#include "common.h"

@implementation iCalAction

- (id)initWithContext:(WOContext *)_ctx {
  self->ctx = [_ctx retain];
  return self;
}
- (void)dealloc {
  [self->ctx release];
  [super dealloc];
}

/* accessors */

- (WOContext *)context {
  return self->ctx;
}
- (WORequest *)request {
  return [self->ctx request];
}
- (id)application {
  return [WOApplication application];
}

- (NSString *)requestUser {
  NSRange  r;
  NSString *s;
  
  s = [[self request] requestHandlerPath];
  r = [s rangeOfString:@"/"];
  if (r.length == 0) return nil;
  return [s substringToIndex:r.location];
}
- (NSString *)requestCalendarPath {
  NSRange  r;
  NSString *s;
  
  s = [[self request] requestHandlerPath];
  r = [s rangeOfString:@"/"];
  if (r.length == 0) return nil;
  return [s substringFromIndex:(r.location + 1)];
}

/* operation */

- (WOResponse *)run {
  return nil;
}

- (NSString *)credentials {
  WORequest *rq;
  id        creds;
  NSRange   r;
  
  if ((rq = [self->ctx request]) == nil)
    return nil;
  if ((creds = [rq headerForKey:@"authorization"]) == nil)
    return nil;
  
  r = [creds rangeOfString:@" " options:NSBackwardsSearch];
  if (r.length == 0) {
    [self logWithFormat:@"invalid 'authorization' header: '%@'", creds];
    return nil;
  }
  return [creds substringFromIndex:(r.location + r.length)];
}

- (NSString *)credentialsLogin {
  id creds;

  creds = [creds stringByDecodingBase64];
  creds = [creds componentsSeparatedByString:@":"];
  if ([creds count] < 2) {
    [self logWithFormat:@"invalid credentials"];
    return nil;
  }
  
  return [creds objectAtIndex:0];
}

- (iCalPortalDatabase *)database {
  return [(id)[WOApplication application] database];
}

- (iCalPortalUser *)user {
  iCalPortalDatabase *db;
  iCalPortalUser *user;
  id       creds;
  NSString *login, *pwd;
  
  if ((db = [self database]) == nil)
    return nil;
  
  if ((creds = [self credentials]) == nil)
    return nil;
  
  /* assuming basic authentication ... */
  creds = [creds stringByDecodingBase64];
  creds = [creds componentsSeparatedByString:@":"];
  if ([creds count] < 2) {
    [self logWithFormat:@"invalid credentials"];
    return nil;
  }
  
  login = [creds objectAtIndex:0];
  pwd   = [creds objectAtIndex:1];
  
  user = [db userWithName:login password:pwd];
  
  return user;
}

- (NSString *)authRealm {
  WOApplication *app = [self application];
  return [app name];
}

- (WOResponse *)missingAuthResponse {
  WOResponse *resp;
  NSString *auth;

  auth = [NSString stringWithFormat:@"Basic realm=\"%@\"",[self authRealm]];
  
  resp = [(WOResponse *)[WOResponse alloc] initWithRequest:[self request]];
  [resp setStatus:401 /* unauthorized */];
  [resp setHeader:auth forKey:@"www-authenticate"];
  //[resp setHeader:@"close" forKey:@"connection"];
  [resp setHeader:@"text/html; charset=iso-8859-1" forKey:@"content-type"];
  [resp appendContentString:
    @"<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">"
    @"<HTML><HEAD>"
    @"<TITLE>401 Authorization Required</TITLE>"
    @"</HEAD><BODY>"
    @"<H1>Authorization Required</H1>"
    @"<ADDRESS>Apache/1.3.26 Server at dogbert Port 9000</ADDRESS>"
    @"</BODY></HTML>"
   ];
  
  return AUTORELEASE(resp);
}

- (WOResponse *)accessDeniedResponse {
  WOResponse *resp;
  NSString *auth;
  
  auth = [NSString stringWithFormat:@"Basic realm=\"%@\"",[self authRealm]];
  
  [self logWithFormat:@"access was denied"];
  
  resp = [(WOResponse *)[WOResponse alloc] initWithRequest:[self request]];
  [resp setStatus:403 /* forbidden */];
  [resp setHeader:auth forKey:@"www-authenticate"];
  return [resp autorelease];
}

- (WOResponse *)notFoundResponse {
  WOResponse *resp;
  
  resp = [(WOResponse *)[WOResponse alloc] initWithRequest:[self request]];
  [resp setStatus:404 /* not found */];
  return [resp autorelease];
}

@end /* iCalAction */

@implementation iCalFakeAction

- (id)initWithContext:(WOContext *)_ctx code:(int)_status {
  if ((self = [super initWithContext:_ctx])) {
    self->code = _status;
  }
  return self;
}

- (id)initWithContext:(WOContext *)_ctx {
  return [self initWithContext:_ctx code:200];
}

- (WOResponse *)run {
  WOResponse *r;
  
  r = [WOResponse responseWithRequest:[self request]];
  [r setStatus:self->code];
  
  [r setHeader:@"close" forKey:@"connection"];
  [r setHeader:@"text/plain; charset=iso-8859-1" forKey:@"content-type"];
  
  [r appendContentString:@"operation executed\r\n"];
  
  return r;
}

@end /* iCalFakeAction */
