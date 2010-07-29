//
// Application.m
// Project WOExtTest
//
// Created by helge on Mon Feb 16 2004
//

#include "Application.h"

@implementation Application

- (id)init {
  if ((self = [super init])) {
    WORequestHandler *rh;
    
    rh = [[NSClassFromString(@"OWViewRequestHandler") alloc] init];
    [self setDefaultRequestHandler:rh];
    [self registerRequestHandler:rh
          forKey:[WOApplication componentRequestHandlerKey]];
    [rh release]; rh = nil;
  }
  return self;
}

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  printf("%s\n", [[_exc description] cString]);
  abort();
}

@end /* Application */
