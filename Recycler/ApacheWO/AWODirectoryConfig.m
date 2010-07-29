// $Id: AWODirectoryConfig.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "AWODirectoryConfig.h"
#include "ApacheWO.h"
#include <ApacheAPI/ApacheResourcePool.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequestHandler.h>
#include "common.h"

@implementation AWODirectoryConfig

- (id)init {
  return self;
}

- (id)initWithConfig:(AWODirectoryConfig *)_cfg {
  if ((self = [self init])) {
    self->application = [_cfg->application retain];
    self->rqHandler   = [_cfg->rqHandler   retain];
  }
  return self;
}

- (id)initWithBaseConfig:(AWODirectoryConfig *)_base
  andConfig:(AWODirectoryConfig *)_new
{
  if ((self = [self initWithConfig:_base])) {
    if (_new->application)
      ASSIGN(self->application, _new->application);
    if (_new->rqHandler)
      ASSIGN(self->rqHandler, _new->rqHandler);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->application);
  RELEASE(self->rqHandler);
  [super dealloc];
}
+ (id)mergeBaseConfig:(AWODirectoryConfig *)_base
  withNewConfig:(AWODirectoryConfig *)_new
{
  return [[[self alloc] initWithBaseConfig:_base andConfig:_new] autorelease];
}

- (NSString *)stringValue {
  return [self description];
}
- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if ((tmp = [self application]))
    [ms appendFormat:@" app=%@(0x%p)", [(WOApplication *)tmp name], tmp];
  if ((tmp = [self requestHandler]))
    [ms appendFormat:@" rqh=%@", tmp];
  
  [ms appendString:@">"];
  return ms;
}

/* configuration */

- (void)setApplication:(WOApplication *)_app {
  ASSIGN(self->application, _app);
}
- (WOApplication *)application {
  return self->application;
}

- (void)setRequestHandler:(WORequestHandler *)_handler {
  ASSIGN(self->rqHandler, _handler);
}
- (WORequestHandler *)requestHandler {
  return self->rqHandler;
}

/* commands */

- (id)SetSxApplication:(NSString *)_key {
  WOApplication *app;

  if ((app = [self application])) {
    [self logWithFormat:@"application already set !"];
  }
  
  if ((app = [ApacheWO applicationForKey:_key className:nil]) == nil) {
    [self logWithFormat:@"got no application for key '%@'", _key];
  }
  else {
    [self setApplication:app];
  }
  
  return nil /* nil means 'no error' */;
}

- (id)SetSxRequestHandler:(NSString *)_className {
  WORequestHandler *rqh;
  Class rqhClazz;
  
  if ((rqh = [self requestHandler])) {
    [self logWithFormat:@"requestHandler already set !"];
  }
  
  if ((rqhClazz = NSClassFromString(_className)) == Nil) {
    return [NSString stringWithFormat:
                       @"did not find request handler for class '%@'",
                       _className];
  }
  
  if ((rqh = [[rqhClazz alloc] init]) == nil) {
    return [NSString stringWithFormat:
                       @"could not allocate request handler of class '%@'",
                       _className];
  }

  [self setRequestHandler:rqh];
  RELEASE(rqh);
  
  return nil /* nil means 'no error' */;
}

- (id)LogText:(NSString *)_txt {
  if ([_txt length] == 0)
    /* return an error text */
    return @"missing echo text !";
  
  //[self appendString:_txt];
  
  return nil /* nil means 'no error' */;
}

@end /* AWODirectoryConfig */
