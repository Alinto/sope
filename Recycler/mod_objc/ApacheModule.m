// $Id: ApacheModule.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheModule.h"
#include "ApacheCmdParms.h"
#include "ApacheResourcePool.h"
#import <Foundation/Foundation.h>
#include "httpd.h"

int ApacheDeclineRequest = DECLINED;
int ApacheHandledRequest = OK;

@implementation ApacheModule

- (NSString *)usageForConfigSelector:(SEL)_selector {
  return nil;
}

/* logging */

- (void)logWithFormat:(NSString *)_format, ... {
  NSString *value = nil;
  va_list  ap;

  va_start(ap, _format);
  value = [NSString stringWithFormat:_format arguments:ap];
  va_end(ap);
  
#if DEBUG
  printf("|0x%p| %s\n", (unsigned int)self, [[value description] cString]);
#else
  NSLog(@"|0x%p| %@", self, value);
#endif
}
- (void)debugWithFormat:(NSString *)_format, ... {
  static char showDebug = 2;
  NSString *value = nil;
  va_list  ap;
  
  if (showDebug == 2) {
#if 0
    showDebug = [WOApplication isDebuggingEnabled] ? 1 : 0;
#endif
  }
  
  if (showDebug) {
    va_start(ap, _format);
    value = [NSString stringWithFormat:_format arguments:ap];
    va_end(ap);
    
#if DEBUG
    printf("|0x%p|D %s\n", (unsigned int)self,
           [[value description] cString]);
#else
    NSLog(@"|0x%p|D %@", self, value);
#endif
  }
}

@end /* ApacheModule */
