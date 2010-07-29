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

#ifndef __SxComponents_SxBasicAuthCredentials_H__
#define __SxComponents_SxBasicAuthCredentials_H__

#import <Foundation/NSObject.h>

@class NSString;
@class WOResponse, WORequest;

/*
  HTTP Basic Authentication
  
  Credentials with an empty realm will be applied to any basic request !!
  (more convenient, but [much] less secure !!!)
*/

@interface SxBasicAuthCredentials : NSObject
{
  NSString *realm;
  NSString *userName;
  NSString *httpCred;
}

- (id)initWithRealm:(NSString *)_realm
  userName:(NSString *)_userName
  password:(NSString *)_pwd;

/* basic auth info */

- (NSString *)realm;
- (NSString *)userName;

/* accessor methods to fill out credentials within an exception object */
- (void)setCredentials:(NSString *)_username password:(NSString *)_password;

/* backend */

- (BOOL)usableWithHttpResponse:(WOResponse *)_response;
- (void)applyOnRequest:(WORequest *)_request;

@end

#endif /* __SxComponents_SxBasicAuthCredentials_H__ */
