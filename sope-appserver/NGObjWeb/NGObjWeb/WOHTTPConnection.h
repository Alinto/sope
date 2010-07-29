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

#ifndef __NGObjWeb_WOHTTPConnection_H__
#define __NGObjWeb_WOHTTPConnection_H__

#import <Foundation/NSObject.h>

/*
  WOHTTPConnection
  
  This class can be used to access HTTP based services using the
  NGObjWeb infrastructure.
*/

@class NSURL;
@class NGCTextStream;
@class WORequest, WOResponse, NSException;

@interface WOHTTPConnection : NSObject
{
  NSURL         *url;
  
  BOOL          keepAlive;
  int           connectTimeout;
  int           sendTimeout;
  int           receiveTimeout;
  
  BOOL          useProxy;
  BOOL          useSSL;
  
  id            socket;
  id            log;
  NGCTextStream *io;
  NSException   *lastException;
  
  BOOL didRegisterForNotification;
}

- (id)initWithHost:(NSString *)_h onPort:(unsigned int)_p secure:(BOOL)_flag;
- (id)initWithHost:(NSString *)_hostName onPort:(unsigned int)_port;
- (id)initWithURL:(id)_url;

/* IO */

- (BOOL)sendRequest:(WORequest *)_request;
- (WOResponse *)readResponse;

- (void)setKeepAliveEnabled:(BOOL)_flag;
- (BOOL)keepAliveEnabled;

/* timeouts */

- (void)setConnectTimeout:(int)_seconds;
- (int)connectTimeout;
- (void)setReceiveTimeout:(int)_seconds;
- (int)receiveTimeout;
- (void)setSendTimeout:(int)_seconds;
- (int)sendTimeout;

@end

extern NSString *WOHTTPConnectionCanReadResponse;

@interface WOHTTPConnection(SkyrixAdds)

/* error handling */

- (NSException *)lastException;

@end

#endif /* __NGObjWeb_WOHTTPConnection_H__ */
