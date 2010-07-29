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

#ifndef __NGXmlRpc_NGXmlRpcAction_H__
#define __NGXmlRpc_NGXmlRpcAction_H__

#import <Foundation/NSObject.h>
#import <NGObjWeb/WOActionResults.h>
#include <NGObjWeb/WOApplication.h>
#include <NGXmlRpc/WODirectAction+XmlRpc.h>

@class NSArray, NSString, NSException;
@class XmlRpcMethodCall;
@class NGAsyncResultProxy;
@class WORequest;

@interface NGXmlRpcAction : NSObject
{
@protected
  WOContext *context;
}

/* initializer */

- (id)initWithContext:(WOContext *)_context;

/* accessors */

- (id)application;
- (WORequest *)request;
- (id)session;
- (id)existingSession;

/* notifications */

- (void)awake;
- (void)sleep;

/* sandstorm components */

- (NSString *)xmlrpcComponentNamespacePrefix;
- (NSString *)xmlrpcComponentName;
- (NSString *)xmlrpcComponentNamespace;

/* XML-RPC direct action dispatcher ... */

- (id)performActionNamed:(NSString *)_name parameters:(NSArray *)_params;
- (id<WOActionResults>)performMethodCall:(XmlRpcMethodCall *)_call;

- (id<WOActionResults>)missingAuthAction;
- (id<WOActionResults>)accessDeniedAction;

- (id<WOActionResults>)actionResponseForResult:(id)resValue;

/* async operation*/

- (WOResponse *)responseForAsyncResult:(NGAsyncResultProxy *)_proxy;

/* command context */

- (BOOL)hasAuthorizationHeader;
- (NSString *)credentials;

@end

@interface NGXmlRpcAction(Registry)

/* class registry */

+ (void)registerActionClass:(Class)_class forURI:(NSString *)_uri;
+ (Class)actionClassForURI:(NSString *)_uri;

/* action registry */

+ (BOOL)registerMappingsInFile:(NSString *)_path;

+ (void)registerSelector:(SEL)_selector
  forMethodNamed:(NSString *)_method
  signature:(id)_signature; /* either array or CSV */

+ (SEL)selectorForActionNamed:(NSString *)_name
  signature:(NSArray *)_signature;

+ (NSArray *)registeredMethodNames; /* can be used for listMethods */
+ (NSArray *)signaturesForMethodNamed:(NSString *)_method;
+ (NSArray *)registeredMethodNames;

@end

@interface WOApplication(XmlRpcActionClass)

- (Class)defaultActionClassForRequest:(WORequest *)_request;

@end

#endif /* __NGXmlRpc_NGXmlRpcAction_H__ */
