// $Id: AWOServerConfig.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "AWOServerConfig.h"
#include "AliasMap.h"
#include <ApacheAPI/ApacheResourcePool.h>
#include <ApacheAPI/ApacheServer.h>
#include <ApacheAPI/ApacheCmdParms.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequestHandler.h>
#include "common.h"

@implementation AWOServerConfig

- (id)initWithServer:(ApacheServer *)_server {
  //NSLog(@"%s: init with server: %@", __PRETTY_FUNCTION__, _server);
  self->appAlias     = [[AliasMap alloc] initWithCapacity:8];
  self->handlerAlias = [[AliasMap alloc] initWithCapacity:8];
  return self;
}

- (id)initWithConfig:(AWOServerConfig *)_cfg {
  if ((self = [self init])) {
    self->appAlias = [[AliasMap alloc] initWithAliasMap:_cfg->appAlias];
    self->handlerAlias = 
      [[AliasMap alloc] initWithAliasMap:_cfg->handlerAlias];
  }
  return self;
}

- (id)initWithBaseConfig:(AWOServerConfig *)_base
  andConfig:(AWOServerConfig *)_new
{
  if ((self = [self initWithConfig:_base])) {
    [self->appAlias addEntriesFromAliasMap:_new->appAlias];
    [self->handlerAlias addEntriesFromAliasMap:_new->handlerAlias];
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->appAlias);
  RELEASE(self->handlerAlias);
  [super dealloc];
}

+ (id)mergeBaseConfig:(AWOServerConfig *)_base
  withNewConfig:(AWOServerConfig *)_new
{
  return [[[self alloc] initWithBaseConfig:_base andConfig:_new] autorelease];
}

- (NSString *)stringValue {
  return [self description];
}
- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" appAlias=%@", self->appAlias];
  
  [ms appendString:@">"];
  return ms;
}

/* commands */

- (id)SxApplicationAlias:(NSString *)_name:(NSString *)_uri {
  NSString *tmp;
  
  if ((tmp = [self->appAlias uriForKey:_name baseURI:@"/"])) {
    return [NSString stringWithFormat:@"app %@ already mapped to %@",
		       _name, tmp];
  }
  
  //[self logWithFormat:@"aliasing app %@ to %@", _name, _uri];
  
  [self->appAlias mapKey:_name toURI:_uri];
  
  return nil /* nil means 'no error' */;
}

- (id)SxHandlerAlias:(NSString *)_handler:(NSString *)_uri {
  NSString *tmp;
  
  if ((tmp = [self->handlerAlias uriForKey:_handler baseURI:@"/"])) {
    return [NSString stringWithFormat:@"handler %@ already mapped to %@",
		       _handler, tmp];
  }
  
  //[self logWithFormat:@"aliasing handler %@ to %@", _handler, _uri];
  
  [self->handlerAlias mapKey:_handler toURI:_uri];
  
  return nil /* nil means 'no error' */;
}

- (id)LoadBundle:(NSString *)_bundleName {
  [self logWithFormat:@"should load bundle %@", _bundleName];
  return nil;
}

@end /* AWOServerConfig */
