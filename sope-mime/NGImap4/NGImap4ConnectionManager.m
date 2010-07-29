/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "NGImap4ConnectionManager.h"
#include "NGImap4Connection.h"
#include "NGImap4Client.h"
#include "imCommon.h"

@implementation NGImap4ConnectionManager

static BOOL           debugOn    = NO;
static BOOL           debugCache = NO;
static BOOL           poolingOff = NO;
static NSTimeInterval PoolScanInterval = 5 * 60 /* every five minutes */;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn      = [ud boolForKey:@"NGImap4EnableIMAP4Debug"];
  debugCache   = [ud boolForKey:@"NGImap4EnableIMAP4CacheDebug"];
  poolingOff   = [ud boolForKey:@"NGImap4DisableIMAP4Pooling"];
  
  if ([ud objectForKey:@"NGImap4PoolingCleanupInterval"])
    PoolScanInterval = [[ud objectForKey:@"NGImap4PoolingCleanupInterval"] doubleValue];

  if (debugOn)    NSLog(@"Note: NGImap4EnableIMAP4Debug is enabled!");
  if (poolingOff) NSLog(@"WARNING: IMAP4 connection pooling is disabled!");
}

+ (id)defaultConnectionManager {
  static NGImap4ConnectionManager *manager = nil; // THREAD
  if (manager == nil) 
    manager = [[self alloc] init];
  return manager;
}

- (id)init {
  if ((self = [super init])) {
    if (!poolingOff) {
      self->urlToEntry = [[NSMutableDictionary alloc] initWithCapacity:256];
      self->gcTimer = [[NSTimer scheduledTimerWithTimeInterval:
				  PoolScanInterval
				target:self selector:@selector(_garbageCollect:)
				userInfo:nil repeats:YES] retain];
    }
  }
  return self;
}

- (void)dealloc {
  [self->gcTimer invalidate];
  [self->urlToEntry release];
  [self->gcTimer    release];
  [super dealloc];
}

/* cache */

- (id)cacheKeyForURL:(NSURL *)_url {
  // protocol, user, host, port
  return [NSString stringWithFormat:@"%@://%@@%@:%@",
		   [_url scheme], [_url user], [_url host], [_url port]];
}

- (NGImap4Connection *)entryForURL:(NSURL *)_url {
  if (_url == nil)
    return nil;
  
  return [self->urlToEntry objectForKey:[self cacheKeyForURL:_url]];
}
- (void)cacheEntry:(NGImap4Connection *)_entry forURL:(NSURL *)_url {
  if (_entry == nil) _entry = (id)[NSNull null];
  [self->urlToEntry setObject:_entry forKey:[self cacheKeyForURL:_url]];
}

- (void)_garbageCollect:(NSTimer *)_timer {
  // TODO: scan for old IMAP4 channels
  NGImap4Connection *entry;
  NSDate *now;
  NSArray *a;
  int i;

  a = [self->urlToEntry allKeys];
  now = [NSDate date];

  for (i = 0; i < [a count]; i++)
    {
      entry = [self->urlToEntry objectForKey: [a objectAtIndex: i]];

      if ([now timeIntervalSinceDate: [entry creationTime]] > PoolScanInterval)
	{
	  [[entry client] logout];
	  [self->urlToEntry removeObjectForKey: [a objectAtIndex: i]];
	}
    }

  [self debugWithFormat:@"should collect IMAP4 channels (%d active)",
	  [self->urlToEntry count]];
}

- (NGImap4Connection *)connectionForURL:(NSURL *)_url password:(NSString *)_p {
  /*
    Three cases:
    a) not yet connected             => create new entry and connect
    b) connected, correct password   => return cached entry
    c) connected, different password => try to recreate entry
  */
  NGImap4Connection *entry;
  NGImap4Client *client;

  if (poolingOff) {
    client = [self imap4ClientForURL:_url password:_p];
    entry = [[NGImap4Connection alloc] initWithClient:client 
				       password:_p];
    return [entry autorelease];
  }
  else {
  /* check cache */
  
    if ((entry = [self entryForURL:_url]) != nil) {
      if ([entry isValidPassword:_p]) {
	if (debugCache)
	  [self logWithFormat:@"valid password, reusing cache entry ..."];
	return entry;
      }
    
      /* different password, password could have changed! */
      if (debugCache)
	[self logWithFormat:@"different password than cached entry: %@", _url];
      entry = nil;
    }
    else
      [self debugWithFormat:@"no connection cached yet for url: %@", _url];
  
    /* try to login */
  
    client = [entry isValidPassword:_p]
      ? [entry client]
      : [self imap4ClientForURL:_url password:_p];
    
    if (client == nil)
      return nil;
  
  /* sideeffect of -imap4ClientForURL:password: is to create a cache entry */
    return [self entryForURL:_url];
  }
}

/* client object */

- (NGImap4Client *)imap4ClientForURL:(NSURL *)_url password:(NSString *)_pwd {
  // TODO: move to some global IMAP4 connection pool manager
  NGImap4Connection *entry;
  NGImap4Client *client;
  NSDictionary  *result;
  
  if (_url == nil)
    return nil;

  /* check connection pool */
  
  if ((entry = [self entryForURL:_url]) != nil) {
    if ([entry isValidPassword:_pwd]) {
      [self debugWithFormat:@"reused IMAP4 connection for URL: %@", _url];
      return [entry client];
    }
    
    /* different password, password could have changed! */
    entry = nil;
  }
  
  /* setup connection and attempt login */
  
  if ((client = [NGImap4Client clientWithURL:_url]) == nil)
    return nil;
  
  result = [client login:[_url user] password:_pwd];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat:
            @"IMAP4 login failed:\n"
	    @"  host=%@, user=%@, pwd=%s\n"
	    @"  url=%@\n  base=%@\n  base-class=%@)\n"
	    @"  = %@", 
            [_url host], [_url user], [_pwd length] > 0 ? "yes" : "no", 
	    [_url absoluteString],
	    [_url baseURL],
            NSStringFromClass([[_url baseURL] class]),
            client];
    return nil;
  }
  
  [self debugWithFormat:@"created new IMAP4 connection for URL: %@", _url];
  
  /* cache connection in pool */
  
  entry = [[NGImap4Connection alloc] initWithClient:client 
					   password:_pwd];
  [self cacheEntry:entry forURL:_url];
  [entry release]; entry = nil;
  
  return client;
}

- (void)flushCachesForURL:(NSURL *)_url {
  NGImap4Connection *entry;
  
  if ((entry = [self entryForURL:_url]) == nil) /* nothing cached */
    return;
  
  [entry flushFolderHierarchyCache];
  [entry flushMailCaches];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* NGImap4ConnectionManager */
