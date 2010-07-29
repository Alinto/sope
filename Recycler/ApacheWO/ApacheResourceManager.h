// $Id: ApacheResourceManager.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __ApacheResourceManager_H__
#define __ApacheResourceManager_H__

#include <NGObjWeb/WOResourceManager.h>

@class NSMutableDictionary;
@class ApacheRequest;
@class AWODirectoryConfig;
@class WOComponent;

@interface ApacheResourceManager : WOResourceManager
{
  ApacheRequest       *request;
  AWODirectoryConfig  *config;
  NSMutableDictionary *nameToURL;
  WOComponent         *component; /* non-retained */
}

- (id)initWithApacheRequest:(ApacheRequest *)_rq
  config:(AWODirectoryConfig *)_cfg;

@end

#endif /* __ApacheResourceManager_H__ */
