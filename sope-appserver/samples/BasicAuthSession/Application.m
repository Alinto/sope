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

#include <NGObjWeb/WOApplication.h>

@interface Application : WOApplication
@end

#include "NSString+BasicAuth.h"
#include <NGObjWeb/NGObjWeb.h>
#include "common.h"

@interface NSString(ValidSessionID)
- (NSString *)asValidSessionIDString;
@end

@implementation NSString(ValidSessionID)

- (NSString *)asValidSessionIDString {
  unsigned len;

  if ((len = [self length]) == 0)
    return nil;
  else if (len == 18)
    return [[self copy] autorelease];
  else if (len > 18)
    return [self substringToIndex:18];
  else {
    /* increase string length .. */
    NSMutableString *sid;
    
    sid = [[self mutableCopy] autorelease];
    while ([sid length] < 18)
      [sid appendString:@"X"];
    return sid;
  }
}

@end /* NSString(ValidSessionID) */

@implementation Application

- (id)init {
  if ((self = [super init])) {
    WORequestHandler *rh;
    
    rh = [[NSClassFromString(@"OWViewRequestHandler") alloc] init];
    [self setDefaultRequestHandler:rh];
    [self registerRequestHandler:rh
          forKey:[WOApplication componentRequestHandlerKey]];
    RELEASE(rh); rh = nil;
  }
  return self;
}

/* auth check */

- (BOOL)isValidAuthorization:(NSString *)_credentials
  inContext:(WOContext *)_ctx
{
  NSString *login, *pwd;

  login = [_credentials loginOfHTTPBasicAuthorizationValue];
  pwd   = [_credentials passwordOfHTTPBasicAuthorizationValue];

  [self debugWithFormat:@"login '%@', pwd=%s", login, [pwd length]?"yes":"no"];
  
  return [login length] > 0;
}

- (NSString *)sessionIDForAuthorization:(NSString *)_credentials
  inContext:(WOContext *)_ctx
{
  return [[_credentials loginOfHTTPBasicAuthorizationValue]
                        asValidSessionIDString];
}

/* session callbacks */

- (WOSession *)createSessionForRequest:(WORequest *)_request {
  [self debugWithFormat:@"creating session ..."];
  return [super createSessionForRequest:_request];
}

- (WOResponse *)handleSessionCreationErrorInContext:(WOContext *)_ctx {
  /* a session could not be created */
  WOResponse *response;
  NSString   *header;
  
  header = [NSString stringWithFormat:@"basic realm=\"%@\"", [self name]];
  
  response = [_ctx response];
  [response setStatus:401 /* unauthorized */];
  [response setContent:[NSData data]];
  [response setHeader:header forKey:@"www-authenticate"];
  return response;
}

- (WOResponse *)handleSessionRestorationErrorInContext:(WOContext *)_ctx {
  /*
    A session could not be restored, an ID is available

    This is too late to create a session, so use the thing below ...
  */
  return [super handleSessionRestorationErrorInContext:_ctx];
}
- (WOSession *)restoreSessionWithID:(NSString *)_sid
  inContext:(WOContext *)_ctx
{
  WOSession *sn;

  if ([_sid length] == 0)
    return nil;
  
  if ((sn = [super restoreSessionWithID:_sid inContext:_ctx]))
    return sn;
  
  /* have a valid? sid, so create a session ... */
  [self debugWithFormat:@"couldn't restore sid '%@', create a new session ..",
          _sid];
  return [self createSessionForRequest:[_ctx request]];
}

/* generating session IDs */

- (NSString *)sessionIDFromRequest:(WORequest *)_request {
  /* session id must be 18 chars long for snsd to work ! */
  NSString *sid;

  if ((sid = [super sessionIDFromRequest:_request]))
    return sid;
  
  /* if no 'regular' session ID is provided, use authorization header .. */
  
  if ((sid = [_request headerForKey:@"authorization"])) {
    if ([self isValidAuthorization:sid inContext:nil]) {
      sid = [self sessionIDForAuthorization:sid inContext:nil];
      [self debugWithFormat:@"got sid from auth: '%@'", sid];
      return sid;
    }
    else {
      [self logWithFormat:@"got invalid auth: '%@'", sid];
      sid = nil;
    }
  }
  return nil;
}

- (NSString *)createSessionIDForSession:(WOSession *)_session {
  /* session id must be 18 chars long for snsd to work ! */
  NSString  *sid;
  WORequest *request;

  request = [[self context] request];
  
  if ((sid = [request headerForKey:@"authorization"])) {
    if ([self isValidAuthorization:sid inContext:nil]) {
      sid = [self sessionIDForAuthorization:sid inContext:[self context]];
      [self debugWithFormat:@"got sid from auth: '%@'", sid];
      return sid;
    }
    else {
      [self logWithFormat:@"got invalid auth: '%@'", sid];
      sid = nil;
    }
  }
  return nil;
}

@end /* Application */

int main(int argc, char **argv) {
  WOApplicationMain(@"Application", argc, (void*)argv);
  exit(0);
  return 0;
}
