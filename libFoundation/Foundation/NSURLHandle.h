/* 
   NSURLHandle.h

   Copyright (C) 2000 MDlink GmbH, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSURLHandle_h__
#define __NSURLHandle_h__

#include <Foundation/NSObject.h>

@class NSURL, NSURLHandle, NSString, NSData, NSMutableArray;

@protocol NSURLHandleClient

- (void)URLHandleResourceDidBeginLoading:(NSURLHandle *)_handler;
- (void)URLHandleResourceDidCancelLoading:(NSURLHandle *)_handler;
- (void)URLHandleResourceDidFinishLoading:(NSURLHandle *)_handler;

- (void)URLHandle:(NSURLHandle *)_handler
  resourceDataDidBecomeAvailable:(NSData *)_data;
- (void)URLHandle:(NSURLHandle *)_handler
  resourceDidFailLoadingWithReason:(NSString *)_reason;

@end

typedef enum {
    NSURLHandleNotLoaded,
    NSURLHandleLoadSucceeded,
    NSURLHandleLoadInProgress,
    NSURLHandleLoadFailed
} NSURLHandleStatus;

@interface NSURLHandle : NSObject
{
    NSMutableArray *clients;
}

+ (Class)URLHandleClassForURL:(NSURL *)_url;
+ (void)registerURLHandleClass:(Class)_clazz;

+ (NSURLHandle *)cachedHandleForURL:(NSURL *)_url;
+ (BOOL)canInitWithURL:(NSURL *)_url;

- (id)initWithURL:(NSURL *)_url cached:(BOOL)_flag;

/* loading */

- (NSData *)loadInForeground;
- (void)loadInBackground;
- (void)beginLoadInBackground;
- (void)endLoadInBackground;
- (NSURLHandleStatus)status;

/* clients */

- (void)addClient:(id<NSURLHandleClient>)_client;
- (void)removeClient:(id<NSURLHandleClient>)_client;

/* reading data */

- (NSData *)resourceData;
- (void)flushCachedData;

/* writing data */

- (BOOL)writeData:(NSData *)_data;

/* properties */

- (id)propertyForKey:(NSString *)_propertyKey;
- (id)propertyForKeyIfAvailable:(NSString *)_propertyKey;
- (BOOL)writeProperty:(id)_propValue forKey:(NSString *)_propertyKey;

@end

#endif /* __NSURLHandle_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
