// $Id: AWODirectoryConfig.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __AWODirectoryConfig_H__
#define __AWODirectoryConfig_H__

#import <Foundation/NSObject.h>

@class WOApplication, WORequestHandler;
@class ApacheResourcePool, ApacheCmdParms;

@interface AWODirectoryConfig : NSObject
{
  WOApplication    *application;
  WORequestHandler *rqHandler;
}

/* configuration */

- (void)setApplication:(WOApplication *)_app;
- (WOApplication *)application;

- (void)setRequestHandler:(WORequestHandler *)_handler;
- (WORequestHandler *)requestHandler;

@end

#endif /* __AWODirectoryConfig_H__ */
