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

#ifndef __NGObjWeb_WOProxyRequestHandler_H__
#define __NGObjWeb_WOProxyRequestHandler_H__

#import <NGObjWeb/WORequestHandler.h>

@class WOHTTPConnection;

/*
  This request-handler can be used to forward and debug HTTP requests. It
  can log requests/responses to stdout and it can perform some request
  manipulations:
    rewriteHost     => change the host: header to match the destination
    connectionClose => replace the connection handler with connection: close
*/

@interface WOProxyRequestHandler : WORequestHandler
{
  WOHTTPConnection *client;
  BOOL     rawLogRequest;
  BOOL     rawLogResponse;
  BOOL     rewriteHost;
  BOOL     connectionClose;
  NSString *logFilePrefix;
  int      rqcount;
}

- (id)initWithHost:(NSString *)_hostName onPort:(unsigned int)_port;

/* settings */

- (void)enableRawLogging;
- (void)setLogFilePrefix:(NSString *)_p;

/* fixups */

- (WORequest *)fixupRequest:(WORequest *)_request;
- (WOResponse *)fixupResponse:(WOResponse *)_r;

@end

#endif /* __NGObjWeb_WOProxyRequestHandler_H__ */
