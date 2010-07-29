// $Id: ApTest.m,v 1.1 2004/06/08 11:15:58 helge Exp $

#include "ApacheModule.h"
#import <Foundation/Foundation.h>

@interface ApTest : ApacheModule
@end

#include "ApacheResourcePool.h"

@implementation ApTest

- (id)init {
  //printf("INIT 0x%p ..\n", (unsigned int)self);
  return self;
}
- (void)dealloc {
  //printf("DEALLOC 0x%p ..\n", (unsigned int)self);
  [super dealloc];
}

/* config commands */

- (id)configureDirectory_MyDirAlias:(NSString *)_fake:(NSString *)_real
  directoryConfig:(id)_cfg
  parameters:(ApacheCmdParms *)_params
{
  [self logWithFormat:@"MyDirAlias(%@,%@,config=%@)", _fake, _real, _cfg];
  [_cfg setObject:_real forKey:_fake];
  return nil;
}
- (id)configureServer_MyServerAlias:(NSString *)_fake:(NSString *)_real
  parameters:(ApacheCmdParms *)_params
{
  [self logWithFormat:@"MyServerAlias(%@,%@)", _fake, _real];
  return nil;
}

- (id)configureDirectory_PrintDirConfig:(NSString *)_fake
  directoryConfig:(id)_cfg
  parameters:(ApacheCmdParms *)_params
{
  [self logWithFormat:@"DIR: %@", _cfg];
  return nil;
}

/* handlers */

- (int)handleTextHtmlRequest:(ApacheRequest *)_rq {
  printf("%s ...\n", __PRETTY_FUNCTION__);
  return ApacheDeclineRequest;
}
- (int)performApTestRequest:(ApacheRequest *)_rq {
  printf("%s ...\n", __PRETTY_FUNCTION__);
  return ApacheDeclineRequest;
}

/* callbacks */

#if 0
- (void)initializeModuleForServer:(ApacheServer *)_server
  inPool:(ApacheResourcePool *)_pool
{
  [self debugWithFormat:@"init module for server %@", _server];
}
#endif

- (id)createPerDirectoryConfigInPool:(ApacheResourcePool *)_pool {
  NSMutableDictionary *md;
  
  md = [[NSMutableDictionary alloc] initWithCapacity:128];
  [_pool releaseObject:md];
  return md;
}
- (id)mergePerDirectoryBaseConfig:(id)_base withNewConfig:(id)_new
  inPool:(ApacheResourcePool *)_pool
{
  [self debugWithFormat:@"merge dir config %@ with %@ ..",
          _base, _new];
  return _base;
}

- (id)createPerServerConfig:(ApacheServer *)_server
  inPool:(ApacheResourcePool *)_pool
{
  return [NSMutableDictionary dictionaryWithCapacity:128];
}
- (id)mergePerServerBaseConfig:(id)_base withNewConfig:(id)_new
  inPool:(ApacheResourcePool *)_pool
{
  [self debugWithFormat:@"merge server config %@ with %@ ..",
          _base, _new];
  return nil;
}

- (int)logRequest:(ApacheRequest *)_rq {
  [self logWithFormat:@"REQUEST: %@", _rq];
  return ApacheDeclineRequest;
}

@end /* ApTest */
