/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#include <NGObjWeb/WORequestHandler.h>

@interface WOResourceRequestHandler : WORequestHandler
@end

#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOResourceManager.h>
#include "common.h"

@interface WOResourceManager(PrivateKeyedAccess)

- (id)_dataForKey:(NSString *)_key sessionID:(NSString *)_sid;

@end

@implementation WOResourceRequestHandler

static BOOL debugOn = NO;

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (WOResponse *)_handleWebServerResourcesRequest:(WORequest *)_request {
  WOApplication *app;
  NSArray       *handlerPath = nil;
  WOResponse    *response   = nil;
  NSArray       *languages;
  NSString      *resourceName;
  NSString      *resourcePath;
  NSData        *data;
  
  if (debugOn) [self logWithFormat:@"handle WS request: %@", _request];
  
  if (_request == nil) return nil;
  
  *(&app)     = [WOApplication application];
  handlerPath = [_request requestHandlerPathArray];
  
  /* check for WebServerResources requests ... */
  
  if ([handlerPath count] < 1) {
    if (debugOn) [self logWithFormat:@"path to short: '%@'", handlerPath];
    return nil;
  }
  if (debugOn) [self logWithFormat:@"  check path: '%@'", handlerPath];
  
  /* ok, found a resource request */

  if ([handlerPath count] > 1) {
    NSString *lang;
    
    lang      = [handlerPath objectAtIndex:0];
    lang      = [lang stringByDeletingPathExtension];
    languages = [NSArray arrayWithObject:lang];
    languages = [languages arrayByAddingObjectsFromArray:languages];
    
    resourceName = [handlerPath objectAtIndex:1];
  }
  else {
    languages    = [_request browserLanguages];
    resourceName = [handlerPath objectAtIndex:0];
  }
  
  resourcePath = [[app resourceManager]
                       pathForResourceNamed:resourceName
                       inFramework:nil
                       languages:languages];
  if (debugOn) [self logWithFormat:@"  resource path: '%@'", resourcePath];

  data = (resourcePath != nil)
    ? [NSData dataWithContentsOfFile:resourcePath]
    : nil;
  
  if (data == nil) {
    response = [WOResponse responseWithRequest:_request];
    [response setStatus:404]; /* not found */
    [response setHeader:@"text/html" forKey:@"content-type"];
    [response appendContentString:@"<h3>Resource not found</h3><pre>"];
    [response appendContentHTMLString:@"Name: "];
    [response appendContentHTMLString:resourceName];
    [response appendContentHTMLString:@"\nLanguages: "];
    [response appendContentHTMLString:[languages description]];
    [response appendContentHTMLString:@"\nResourceManager: "];
    [response appendContentHTMLString:[[app resourceManager] description]];
    [response appendContentString:@"</pre>"];
    return response;
  }
  
  //NSLog(@"shall deliver %@", resourcePath);
  
  response = [WOResponse responseWithRequest:_request];
  
  /* determine content-type */
  {
    NSString *ctype;
    NSString *pathExtension;
    
    pathExtension = [resourcePath pathExtension];
    ctype         = @"application/octet-stream";
    
    if ([pathExtension isEqualToString:@"html"])
      ctype = @"text/html";
    else if ([pathExtension isEqualToString:@"gif"])
      ctype = @"image/gif";
    
    [response setHeader:ctype forKey:@"content-type"];
  }
  
  [response setContent:data];
  
  return response;
}

- (WOResponse *)handleRequest:(WORequest *)_request {
  NSArray *handlerPath = nil;
  
  if (debugOn) [self logWithFormat:@"handle request: %@", _request];
  
  if ([[_request requestHandlerKey] isEqualToString:@"WebServerResources"])
    return [self _handleWebServerResourcesRequest:_request];

  handlerPath = [_request requestHandlerPathArray];
  
  if ([handlerPath count] > 0) {
    NSString *rmkey;
    
    rmkey = [handlerPath objectAtIndex:0];
    if ([rmkey length] > 0) {
      WOResourceManager *rm;
      NSDictionary *data;
      
      rm = [[WOApplication application] resourceManager];
      
      if ((data = [rm _dataForKey:rmkey sessionID:nil]) != nil) {
        WOResponse *response;
        
        response = [WOResponse responseWithRequest:_request];
        [response setHeader:[data objectForKey:@"mimeType"]
                  forKey:@"content-type"];
        [response setContent:[data objectForKey:@"data"]];
        return response;
      }
      else {
        [[WOApplication application]
                        logWithFormat:@"WOResourceRequestHandler: "
                          @"didn't find data for resource key '%@'",
                          rmkey];
      }
    }
  }
  
  /* if everything fails, try locating resource in WebServerResources */
  return [self _handleWebServerResourcesRequest:_request];
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[resource-handler]";
}

@end /* WOResourceRequestHandler */
