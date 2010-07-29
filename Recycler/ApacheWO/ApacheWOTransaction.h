// $Id: ApacheWOTransaction.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __ApacheWOTransaction_H__
#define __ApacheWOTransaction_H__

#import <Foundation/NSObject.h>

@class ApacheRequest;
@class WORequest, WOResponse, WOApplication, WORequestHandler;
@class AWODirectoryConfig, AWOServerConfig;
@class ApacheResourceManager;

@interface ApacheWOTransaction : NSObject
{
@public
  ApacheRequest         *request;
  WORequest             *woRequest;
  WOResponse            *woResponse;
  AWODirectoryConfig    *config;
  AWOServerConfig       *serverConfig;
  WOApplication         *application;
  ApacheResourceManager *resourceManager;
}

- (id)initWithApacheRequest:(ApacheRequest *)_rq 
  config:(AWODirectoryConfig *)_cfg
  serverConfig:(AWOServerConfig *)_srvcfg;

/* accessors */

- (WORequest *)request;
- (WOResponse *)response;
- (WOApplication *)application;
- (ApacheRequest *)apacheRequest;

/* activation */

- (void)activate;
- (void)deactivate;

/* dispatch */

- (int)dispatchUsingHandler:(WORequestHandler *)_handler;

@end

#endif /* __ApacheWOTransaction_H__ */
