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

#include "NGFileManagerURL.h"
#include "common.h"

@interface NGFileManagerURLHandle : NSURLHandle
{
  id<NSObject,NGFileManager> fileManager;
  NSString          *path;
  BOOL              shallCache;
  NSURLHandleStatus status;
  NSData            *cachedData;
  NSDictionary      *cachedProperties;
}
@end

@implementation NGFileManagerURL

- (id)initWithPath:(NSString *)_path
  fileManager:(id<NSObject,NGFileManager>)_fm
{
  static BOOL didRegisterHandleClass = NO;
  if (!didRegisterHandleClass) {
    [NSURLHandle registerURLHandleClass:[NGFileManagerURLHandle class]];
    didRegisterHandleClass = YES;
  }
  
  self->path        = [[_fm standardizePath:_path] copy];
  self->fileManager = [_fm retain];
  return self;
}

- (void)dealloc {
  [self->path        release];
  [self->fileManager release];
  [super dealloc];
}

/* accessors */

- (id<NSObject,NGFileManager>)fileManager {
  return self->fileManager;
}

- (NSString *)fragment {
  return nil;
}
- (NSString *)host {
  return nil;
}
- (NSString *)path {
  return self->path;
}
- (NSString *)scheme {
  return nil;
}
- (NSString *)user {
  return nil;
}
- (NSString *)password {
  return nil;
}
- (NSNumber *)port {
  return nil;
}
- (NSString *)query {
  return nil;
}

- (BOOL)isFileURL {
  return NO;
}

@end /* NGFileManagerURL */

@implementation NGFileManagerURLHandle

+ (BOOL)canInitWithURL:(NSURL *)_url {
  return [_url isKindOfClass:[NGFileManagerURL class]] ? YES : NO;
}

- (id)initWithURL:(NSURL *)_url cached:(BOOL)_flag {
  if (![[self class] canInitWithURL:_url]) {
    [self release];
    return nil;
  }

  self->fileManager = [[(NGFileManagerURL *)_url fileManager] retain];
  self->path        = [[_url path] copy];
  self->shallCache  = _flag;
  self->status      = NSURLHandleNotLoaded;
  return self;
}
- (void)dealloc {
  [self->cachedData  release];
  [self->cachedProperties release];
  [self->path        release];
  [self->fileManager release];
  [super dealloc];
}

- (NSData *)loadInForeground {
  [self->cachedProperties release]; self->cachedProperties = nil;
  [self->cachedData       release]; self->cachedData       = nil;
  
  self->cachedData = [[self->fileManager contentsAtPath:self->path] retain];
  self->cachedProperties =
    [[self->fileManager fileAttributesAtPath:self->path traverseLink:YES]
                        copy];
  
  return self->cachedData;
}
- (void)loadInBackground {
  [self loadInBackground];
}

- (void)flushCachedData {
  [self->cachedData       release]; self->cachedData       = nil;
  [self->cachedProperties release]; self->cachedProperties = nil;
}

- (NSData *)resourceData {
  NSData *data;
  
  if (self->cachedData)
    return [[self->cachedData copy] autorelease];
  
  data = [self loadInForeground];
  data = [data copy];
  
  if (!self->shallCache)
    [self flushCachedData];
  
  return [data autorelease];
}

- (NSData *)availableResourceData {
  return [[self->cachedData copy] autorelease];
}

- (NSURLHandleStatus)status {
  return self->status;
}
- (NSString *)failureReason {
  if (self->status != NSURLHandleLoadFailed)
    return nil;
  
  return @"loading of URL failed";
}

/* properties */

- (id)propertyForKey:(NSString *)_key {
  if (self->cachedProperties)
    return [self->cachedProperties objectForKey:_key];
  
  if ([self loadInForeground]) {
    id value;
    
    value = [self->cachedProperties objectForKey:_key];
    value = [value retain];
    
    if (!self->shallCache)
      [self flushCachedData];

    return [value autorelease];
  }
  else {
    [self flushCachedData];
    return nil;
  }
}
- (id)propertyForKeyIfAvailable:(NSString *)_key {
  return [self->cachedProperties objectForKey:_key];
}

/* writing */

- (BOOL)writeData:(NSData *)_data {
  [self flushCachedData];

  return NO;
}

@end /* NGFileManagerURLHandle */
