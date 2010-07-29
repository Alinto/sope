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

#ifndef __SxXmlRpcComponent_H__
#define __SxXmlRpcComponent_H__

#include <SxComponents/SxComponent.h>

/*
  A proxy object for a remote component accessible via
  XML-RPC :-)
*/

@class NSURL, NSDictionary, NSMutableDictionary;
@class NGXmlRpcClient;
@class WOHTTPConnection;

@interface SxXmlRpcComponent : SxComponent
{
  WOHTTPConnection    *httpConnection;
  NSURL               *url;
  NSMutableDictionary *signatureCache;
  id                  lastCredentials;

  int                 retryCnt;
}

/* initialization */

- (id)initWithName:(NSString *)_name
  registry:(SxComponentRegistry *)_registry
  url:(NSURL *)_url;

- (id)initWithName:(NSString *)_name
  namespace:(NSString *)_namespace
  registry:(SxComponentRegistry *)_registry
  url:(NSURL *)_url;

/* accessors */

- (WOHTTPConnection *)httpConnection;
- (NSURL *)url;

- (void)addSuccessfulCredentials:(id)_creds;

/* actions */

- (id)call:(NSString *)_methodName arguments:(NSArray *)_params;

@end

#endif /* __SxXmlRpcComponent_H__ */
