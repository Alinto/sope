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

#ifndef __Networking_NGImap4_NGSieveClient_H__
#define __Networking_NGImap4_NGSieveClient_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGSocketProtocols.h>
#include <NGImap4/NGImap4Support.h>
#include <NGImap4/NGImap4ResponseParser.h>

/*
  NGSieveClient
  
  This implements a client for server stored Sieve scripts as supported by
  the Cyrus IMAP server.
*/

@class NSMutableArray, NSString, NSNumber, NSDictionary, NSArray, NSException;
@class EOQualifier;
@class NGHashMap;
@class NGBufferedStream;

typedef enum {
  UnConnected_NGSieveState = 1,
  NonAuthenticated_NGSieveState,
  Authenticated_NGSieveState,
} NGSieveState;

@interface NGSieveClient : NSObject
{
@protected
  id<NGActiveSocket>    socket;
  id<NGActiveSocket>    previous_socket;
  NGBufferedStream      *io;
  id<NGSocketAddress>   address;
  NGImap4ResponseParser *parser;
  NSException           *lastException;

  BOOL     isLogin;

  NSString *authname;
  NSString *login;
  NSString *password;

  BOOL debug;
  BOOL useTLS;
}

+ (id)clientWithURL:(id)_url;
+ (id)clientWithAddress:(id<NGSocketAddress>)_address;
+ (id)clientWithHost:(id)_host;

- (id)initWithURL:(id)_url;
- (id)initWithHost:(id)_host;
- (id)initWithAddress:(id<NGSocketAddress>)_address;

/* accessors */

- (id<NGActiveSocket>)socket;
- (id<NGSocketAddress>)address;

/* exceptions */

- (NSException *)lastException;
- (void)resetLastException;

/* connection */

- (NSDictionary *)openConnection;
- (void)closeConnection;
- (NSNumber *)isConnected;
- (void)reconnect;

/* commands */

- (NSDictionary *)login:(NSString *)_login password:(NSString *)_passwd;
- (NSDictionary *)login:(NSString *)_login authname:(NSString *)_authname password:(NSString *)_passwd;

- (NSDictionary *)logout;

- (NSString *)getScript:(NSString *)_scriptName;
- (NSDictionary *)putScript:(NSString *)_name script:(NSString *)_script;
- (NSDictionary *)setActiveScript:(NSString *)_name;
- (NSDictionary *)deleteScript:(NSString *)_script;
- (NSDictionary *)listScripts;

/* equality */

- (BOOL)isEqualToSieveClient:(NGSieveClient *)_obj;

@end

#endif /* __Networking_NGSieve_NGSieveClient_H__ */
