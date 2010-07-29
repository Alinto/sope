/*
  Copyright (C) 2004-2005 Helge Hess

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "XmlRpcClientTool.h"
#include "HandleCredentialsClient.h"
#include <NGStreams/NGLocalSocketAddress.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

#define EXIT_FAIL -1

@interface NSObject(Printing)
- (void)printWithTool:(XmlRpcClientTool *)_tool;
@end

@implementation XmlRpcClientTool

/* initialization */

- (id)init {
  return [self initWithArguments:nil];
}

- (id)initWithArguments:(NSArray *)_arguments {
  if ((self = [super init])) {
    NSUserDefaults *ud;
    NSString *s;
    int argc;

    argc = [_arguments count];
    if(argc == 1) {
      [self help:[_arguments objectAtIndex:0]];
      return nil;
    }
    
    s = [_arguments objectAtIndex:1];
    if (![self initXmlRpcClientWithStringURL:s]) {
      printf("Error initializing the XML-RPC client\n");
      [self release];
      return nil;
    }
    
    if (argc > 2) {
      [self initMethodCall:_arguments];
    }
    else {
      self->methodName = @"system.listMethods";
      self->parameters = nil;
    }
    
    ud = [NSUserDefaults standardUserDefaults];
    if ([ud boolForKey:@"forceauth"]) {
      [self->client setUserName:[ud stringForKey:@"login"]];
      [self->client setPassword:[ud stringForKey:@"password"]];
    }
    else {
      [self->client setDefLogin:[ud stringForKey:@"login"]];
      [self->client setDefPassword:[ud stringForKey:@"password"]];
    }
  }
  return self;
}

- (BOOL)initXmlRpcClientWithStringURL:(NSString *)_url {
  NSURL *url = nil;
  
  if (![_url isAbsoluteURL]) {
    /* make a raw, Unix domain socket connection */
    NGLocalSocketAddress *addr;
    
    addr = [NGLocalSocketAddress addressWithPath:_url];
    self->client = [[HandleCredentialsClient alloc] initWithRawAddress:addr];
    return YES;
  }
  
  if ((url = [NSURL URLWithString:_url]) != nil) {
#if 0
    if ((uri = [url path]) == nil)
      uri = @"/RPC2";
#endif
    
    self->client = [(HandleCredentialsClient *)
		     [HandleCredentialsClient alloc] initWithURL:url];
    return YES;

  }
  else {
    printf("Invalid URL\n");
    return NO;
  }
}

- (void)initMethodCall:(NSArray *)_arguments {
  self->methodName = [_arguments objectAtIndex:2];

  if ([_arguments count] > 2) {
    NSRange range = NSMakeRange(3, [_arguments count] - 3);
    self->parameters = [[_arguments subarrayWithRange:range] retain];
  }
}

- (void)dealloc {
  [self->client      release];
  [self->methodName  release];
  [self->parameters  release];
  [super dealloc];
}

/* printing */

- (void)printElement:(id)element {
  [element printWithTool:self];
}

/* printing objects */

- (void)printDictionary:(NSDictionary *)_dict {
  NSEnumerator *dictEnum;
  NSString     *dictKey;
  
  dictEnum = [_dict keyEnumerator];
  while((dictKey = [dictEnum nextObject]) != nil) {
    printf("%s=", [dictKey cString]);    
    [self printElement:[_dict objectForKey:dictKey]];
  }
}

- (void)printArray:(NSArray *)_array {
  NSEnumerator *arrayEnum;
  id arrayElem;
  
  arrayEnum = [_array objectEnumerator];
  while((arrayElem = [arrayEnum nextObject]) != nil) {
    [self printElement:arrayElem];
  }
}

- (void)help:(NSString *)pn {
  fprintf(stderr,
          "usage:    %s <url> [<method-name>] [<arg1>,...]\n"
          "  sample: %s http://localhost:20000/RPC2 bc 1 2\n",
          [pn cString], [pn cString]);
}

/* running */

- (int)run {
  int  exitCode  = 0;
  int  loopCount = 0;
  id   result;

  if (self->client == nil) {
    NSLog(@"missing XML-RPC client object ...");
    return EXIT_FAIL;
  }
  
  do {
    result = [self->client
                  invokeMethodNamed:self->methodName
                  parameters:self->parameters];
    loopCount++;
  }
  while ((result == nil) && loopCount < 20);

  if (result == nil) {
    NSLog(@"call failed, no result (looped %i times) ?!", loopCount);
    return EXIT_FAIL;
  }

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"plist"]) {
    NSString *s;
    
    s = [result description];
    printf("%s\n", [s cString]);
  }
  else
    [self printElement:result];
  
  if ([result isKindOfClass:[NSException class]]) {
    exitCode = 255;
  }

  return exitCode;
}

@end /* XmlRpcClientTool */
