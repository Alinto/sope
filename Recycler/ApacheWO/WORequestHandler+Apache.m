// $Id: WORequestHandler+Apache.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "WORequestHandler+Apache.h"
#include "common.h"

@implementation WORequestHandler(ApacheExt)

- (id)initWithConfig:(NSDictionary *)_cfg {
  return [self init];
}

+ (WORequestHandler *)requestHandlerForConfig:(NSDictionary *)_plist {
  NSString *className;
  Class    clazz;
  
  className = [_plist objectForKey:@"class"];
  if ([className length] == 0)
    return nil;
  
  if ((clazz = NSClassFromString(className)) == Nil) {
    [self logWithFormat:@"did not find request handler class %@", className];
    return nil;
  }
  
  return [[[clazz alloc] initWithConfig:_plist] autorelease];
}

@end /* WORequestHandler(ApacheExt) */
