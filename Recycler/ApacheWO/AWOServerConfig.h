// $Id: AWOServerConfig.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __AWOServerConfig_H__
#define __AWOServerConfig_H__

#import <Foundation/NSObject.h>

@class AliasMap;
@class NSMutableDictionary, NSMutableArray;
@class WOApplication, WORequestHandler;
@class ApacheResourcePool, ApacheServer, ApacheCmdParms;

@interface AWOServerConfig : NSObject
{
@public
  AliasMap *appAlias;
  AliasMap *handlerAlias;
}

@end

#endif /* __AWOServerConfig_H__ */
