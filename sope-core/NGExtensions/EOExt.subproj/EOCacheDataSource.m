/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

//#define PROFILE 1

#include "EOCacheDataSource.h"
#import <EOControl/EOControl.h>
#import "EODataSource+NGExtensions.h"
#import "common.h"
#include <sys/time.h>

@interface EOCacheDataSource(Private)
- (void)_registerForSource:(id)_source;
- (void)_removeObserverForSource:(id)_source;
- (void)_clearCache;
@end

@interface EOCacheDataSourceTimer : NSObject
{
@public
  EOCacheDataSource *ds; /* non-retained! */
}

@end

@implementation EOCacheDataSource

- (id)initWithDataSource:(EODataSource *)_ds {
  if ((self = [super init])) {
    self->source  = [_ds retain];
    self->timeout = 0;
    self->timer   = nil;
    self->time    = 0;
    [self _registerForSource:self->source];
  }
  return self;
}

- (void)dealloc {
  [self _removeObserverForSource:self->source];
  
  [self->timer  invalidate];
  [self->timer  release];
  
  [self->source release];
  [self->cache  release];
  [super dealloc];
}

/* accessors */

- (void)setSource:(EODataSource *)_source {
  if (self->source == _source)
    return;
  
  [self _removeObserverForSource:self->source];
  ASSIGN(self->source, _source);
  [self _registerForSource:self->source];
  [self _clearCache];
}

- (EODataSource *)source {
  return self->source;
}

- (void)setTimeout:(NSTimeInterval)_timeout {
  self->timeout = _timeout;
}
- (NSTimeInterval)timeout {
  return self->timeout;
}

/* operations */

- (NSArray *)fetchObjects {
  BEGIN_PROFILE;

  self->_isFetching = YES;
  
  if (self->time > 0) {
    if (self->time < [[NSDate date] timeIntervalSinceReferenceDate]) {
      [self->cache release]; self->cache = nil;
    }
  }
  if (self->cache == nil) {
    self->time = 0;
    if (self->timer != nil) {
      [self->timer invalidate];
      [self->timer release]; self->timer = nil;
    }
    
    self->cache = [[self->source fetchObjects] retain];
    
    if (self->timeout > 0) {
      EOCacheDataSourceTimer *holder;
      
      /* this object is here to avoid a retain cycle */
      holder = [[EOCacheDataSourceTimer alloc] init];
      holder->ds = self;
      
      self->time =
        [[NSDate date] timeIntervalSinceReferenceDate] + self->timeout;
      
      /* the timer retains the holder, but no the DS */
      self->timer = [[NSTimer scheduledTimerWithTimeInterval:self->timeout
                              target:holder
                              selector:@selector(clear)
                              userInfo:nil repeats:NO] retain];
      
      [holder release]; holder = nil;
    }
    PROFILE_CHECKPOINT("cache miss");
  }
  else {
    PROFILE_CHECKPOINT("cache hit");
  }
  
  self->_isFetching = NO;
  END_PROFILE;
  return self->cache;
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec {
  [self->source setFetchSpecification:_fetchSpec];
}
- (EOFetchSpecification *)fetchSpecification {
  return [self->source fetchSpecification];
}

/* operations */

- (void)insertObject:(id)_obj {
  [self _clearCache];
  [self->source insertObject:_obj];
}

- (void)deleteObject:(id)_obj {
  [self _clearCache];
  [self->source deleteObject:_obj];
}

- (id)createObject {
  return [self->source createObject];
}

- (void)updateObject:(id)_obj {
  [self->source updateObject:_obj];
  [self _clearCache];  
}

- (EOClassDescription *)classDescriptionForObjects {
  return [[self source] classDescriptionForObjects];
}

- (void)clear {
  [self _clearCache];
}

/* description */

- (NSString *)description {
  NSString *fmt;

  fmt = [NSString stringWithFormat:@"<%@[0x%p]: source=%@>",
                    NSStringFromClass([self class]), self,
                    self->source];
  return fmt;
}

/* private methods */

- (void)_registerForSource:(id)_source {
  static NSNotificationCenter *nc = nil;

  if (_source != nil) {
    if (nc == nil)
      nc = [[NSNotificationCenter defaultCenter] retain];
    
    [nc addObserver:self selector:@selector(_clearCache)
        name:EODataSourceDidChangeNotification object:_source];
  }
}

- (void)_removeObserverForSource:(id)_source {
  static NSNotificationCenter *nc = nil;

  if (_source != nil) {
    if (nc == nil)
      nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:EODataSourceDidChangeNotification
        object:_source];
  }
}

 
- (void)_clearCache {
#if DEBUG && 0
  NSLog(@"clearing cache (%s)...", self->_isFetching?"fetching":"");
  if (fgetc(stdin) == 'a')
    abort();
#endif
  
  self->time = 0;
  
  if (self->timer) {
    [self->timer invalidate];
    [self->timer release]; self->timer = nil;
  }
  
  if (self->cache) {
    [self->cache release]; self->cache = nil;
    [self postDataSourceChangedNotification];
  }
}

@end /* EOCacheDataSource */

@implementation EOCacheDataSourceTimer

- (void)clear {
  [self->ds clear];
}

@end /* EOCacheDataSourceTimer */
