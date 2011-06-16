/*
  Copyright (C) 2000-2008 SKYRIX Software AG

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

#import <Foundation/NSObject.h> // required by gstep-base
#import <Foundation/NSURLHandle.h>
#import <Foundation/NSURL.h>

@class WOResponse;

/*
  An URLHandle class which uses WO classes (WOHTTPConnection, WORequest, ..)
  to get/set HTTP resources.
*/

@interface WOHTTPURLHandle : NSURLHandle
{
  NSURL             *url;
  BOOL              shallCache;
  WOResponse        *cachedResponse;
  NSURLHandleStatus status;
}
@end

#include <NGObjWeb/WOHTTPConnection.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include "common.h"

@implementation WOHTTPURLHandle

+ (BOOL)canInitWithURL:(NSURL *)_url {
  return [[_url scheme] isEqualToString:@"http"];
}

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)newUrl
{
  NSURLHandle   *obj = nil;
  NSLog(@"NOTE: WOHTTPURLHandle.m: cachedHandleForURL: caching not yet not yet implemented");
  return obj;
}


- (id)initWithURL:(NSURL *)_url cached:(BOOL)_flag {
  if (![[_url scheme] hasPrefix:@"http"]) {
    NSLog(@"%s: invalid URL scheme %@ for WOHTTPURLHandle !",
          __PRETTY_FUNCTION__, [_url scheme]);
    RELEASE(self);
    return nil;
  }
  
  self->shallCache = _flag;
  self->url        = [_url copy];
  self->status     = NSURLHandleNotLoaded;
  return self;
}
- (void)dealloc {
  [self->cachedResponse release];
  [self->url            release];
  [super dealloc];
}

- (WOResponse *)_fetchURL:(NSURL *)_url {
  WOHTTPConnection *connection;
  WORequest        *request;
  WOResponse       *response = nil;
  NSString         *luri;
  
  connection = [[WOHTTPConnection alloc] initWithHost:[_url host]
                                         onPort:[[_url port] intValue]];
  if (connection == nil) {
    self->status = NSURLHandleLoadFailed;
    return nil;
  }

  if ((luri = [_url path]) == nil) {
    self->status = NSURLHandleLoadFailed;
    return nil;
  }
  
  if ([[_url query] isNotEmpty]) {
    luri = [[luri stringByAppendingString:@"?"]
                  stringByAppendingString:[_url query]];
  }
  
  request = [[WORequest alloc] initWithMethod:@"GET"
                               uri:luri
                               httpVersion:@"HTTP/1.0"
                               headers:nil
                               content:nil
                               userInfo:nil];
  
  if (request == nil) {
    [connection release];
    self->status = NSURLHandleLoadFailed;
    return nil;
  }
  
  if ([connection sendRequest:request]) {
    if ((response = [[connection readResponse] retain])) {
      if (self->shallCache) {
        ASSIGN(self->cachedResponse, response); }
      self->status = NSURLHandleLoadSucceeded;
    }
    else
      self->status = NSURLHandleLoadFailed;
  }
  else {
    self->status = NSURLHandleLoadFailed;
  }
  
  [request    release];
  [connection release];
  
  return [response autorelease];
}

- (NSData *)loadInForeground {
  WOResponse *response;
  NSData     *data;
  
  response = [self _fetchURL:self->url];
  data = [response content];
  RETAIN(data);
  return AUTORELEASE(data);
}
- (void)loadInBackground {
  [self loadInForeground];
}

- (void)flushCachedData {
  RELEASE(self->cachedResponse);
  self->cachedResponse = nil;
}

- (NSData *)resourceData {
  if (self->cachedResponse) {
    NSData *data;

    data = [self->cachedResponse content];
    RETAIN(data);
    return AUTORELEASE(data);
  }

  return [self loadInForeground];
}
- (NSData *)availableResourceData {
  NSData *data;

  data = [self->cachedResponse content];
  RETAIN(data);
  return AUTORELEASE(data);
}

- (NSURLHandleStatus)status {
  return self->status;
}
- (NSString *)failureReason {
  if (self->status != NSURLHandleLoadFailed)
    return nil;

  return @"loading of HTTP URL failed";
}

/* properties */

- (id)propertyForKey:(NSString *)_key {
  WOResponse *response;
  
  if (self->cachedResponse)
    return [self->cachedResponse headerForKey:_key];
  
  response = [self _fetchURL:self->url];
  return [response headerForKey:_key];
}
- (id)propertyForKeyIfAvailable:(NSString *)_key {
  return [self->cachedResponse headerForKey:_key];
}

/* writing */

- (BOOL)writeData:(NSData *)__data {
  WOHTTPConnection *connection;
  WORequest        *request;
  WOResponse       *response;
  
  [self flushCachedData];
  
  connection = [[WOHTTPConnection alloc] initWithHost:[self->url host]
                                         onPort:[[self->url port] intValue]];
  if (connection == nil)
    return NO;
  
  request = [[WORequest alloc] initWithMethod:@"PUT"
                               uri:[self->url path]
                               httpVersion:@"HTTP/1.0"
                               headers:nil
                               content:__data
                               userInfo:nil];
  if (request == nil) {
    RELEASE(connection);
    return NO;
  }
  
  if ([connection sendRequest:request])
    response = [connection readResponse];
  else
    response = nil;
  
  if (response) {
    if ([response status] != 200)
      response = nil;
  }
  
  RELEASE(request);
  RELEASE(connection);
  
  return response ? YES : NO;
}

@end /* WOHTTPURLHandle */
