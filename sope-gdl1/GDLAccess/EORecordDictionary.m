/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include <stdarg.h>
#include <math.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>

#if LIB_FOUNDATION_LIBRARY
#  include <extensions/objc-runtime.h>
#else
#  include <NGExtensions/NGObjectMacros.h>
#endif

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  include <objc/runtime.h>
#  define method_get_imp method_getImplementation
#  define class_get_instance_method class_getInstanceMethod
#endif


#include "EORecordDictionary.h"

@implementation EORecordDictionary

static NSDictionary *emptyDict = nil;

- (id)init  {
  RELEASE(self);
  if (emptyDict == nil) emptyDict = [[NSDictionary alloc] init];
  return [emptyDict retain];
}

- (id)initWithObjects:(id *)_objects forKeys:(id *)_keys 
  count:(NSUInteger)_count
{
  if (_count == 0) {
        RELEASE(self);
	if (emptyDict == nil) emptyDict = [[NSDictionary alloc] init];
	return [emptyDict retain];
  }
  
  if (_count == 1) {
        RELEASE(self);
        return [[NSDictionary alloc]
                              initWithObjects:_objects forKeys:_keys
                              count:_count];
  }
  
  self->count = _count;
  while(_count--) {
	if ((_keys[_count] == nil) || (_objects[_count] == nil)) {
	  [NSException raise:NSInvalidArgumentException
		       format:@"Nil object to be added in dictionary"];
        }
        self->entries[_count].key   = RETAIN(_keys[_count]);
        self->entries[_count].hash  = [_keys[_count] hash];
        self->entries[_count].value = RETAIN(_objects[_count]);
  }
  return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
  // TODO: who calls this method?
  NSEnumerator  *keys;
  unsigned char i;
    
  keys = [dictionary keyEnumerator];
  self->count = [dictionary count];

  for (i = 0; i < self->count; i++) {
    id key = [keys nextObject];
    
    self->entries[i].key   = RETAIN(key);
    self->entries[i].hash  = [key hash];
    self->entries[i].value = RETAIN([dictionary objectForKey:key]);
  }
  return self;
}

- (void)dealloc {
  /* keys are always NSString keys?! */
#if GNU_RUNTIME
  static Class LastKeyClass = Nil;
  static IMP   keyRelease   = 0;
  static unsigned misses = 0, hits = 0;
#endif
  register unsigned char i;
    
  for (i = 0; i < self->count; i++) {
      register NSString *key = self->entries[i].key;
#if GNU_RUNTIME      
      if (*(id *)key != LastKeyClass) {
	LastKeyClass = *(id *)key;
	keyRelease = 
	  method_get_imp(class_get_instance_method(LastKeyClass, 
						   @selector(release)));
	misses++;
      }
      else
	hits++;
      
      keyRelease(key, NULL /* dangerous? */);

#if PROF_METHOD_CACHE
      if (hits % 1000 == 0 && hits != 0)
	NSLog(@"%s: DB HITS: %d MISSES: %d", __PRETTY_FUNCTION__,hits, misses);
#endif
#else
      [key release];
#endif

      RELEASE(self->entries[i].value);
  }
  [super dealloc];
}

/* operations */

- (id)objectForKey:(id)aKey {
  register EORecordDictionaryEntry *e = self->entries;
  register signed char i;
  register unsigned hash;
#if GNU_RUNTIME
  static Class LastKeyClass = Nil;
  static unsigned (*keyHash)(id,SEL)  = 0;
  static BOOL     (*keyEq)(id,SEL,id) = 0;
#if PROF_METHOD_CACHE
  static unsigned misses = 0, hits = 0;
#endif
#endif
  
#if GNU_RUNTIME      
  if (aKey == nil)
    return nil;
  
  if (*(id *)aKey != LastKeyClass) {
    LastKeyClass = *(id *)aKey;
    keyHash = (void *)
      method_get_imp(class_get_instance_method(LastKeyClass, 
					       @selector(hash)));
    keyEq = (void *)
      method_get_imp(class_get_instance_method(LastKeyClass, 
					       @selector(isEqual:)));
  }
  
  hash = keyHash(aKey, NULL /* dangerous? */);
#else  
  hash = [aKey hash];
#endif

  for (i = (self->count - 1); i >= 0; i--, e++) {
    if (e->hash != hash)
      continue;
    if (e->key == aKey)
      return e->value;
    
#if GNU_RUNTIME
    if (keyEq(e->key, NULL /* dangerous? */, aKey))
      return e->value;
#else
    if ([e->key isEqual:aKey]) 
      return e->value;
#endif
  }
  return nil;
}

- (NSUInteger)count {
  return self->count;
}
- (BOOL)isNotEmpty {
  return self->count > 0 ? YES : NO;
}

- (NSEnumerator *)keyEnumerator {
  return [[[_EORecordDictionaryKeyEnumerator alloc]
            initWithDictionary:self
            firstEntry:self->entries count:self->count] autorelease];
}

@end /* NSConcreteSmallDictionary */

@implementation _EORecordDictionaryKeyEnumerator

- (id)initWithDictionary:(EORecordDictionary *)_dict
  firstEntry:(EORecordDictionaryEntry *)_firstEntry
  count:(unsigned char)_count
{
    self->dict         = RETAIN(_dict);
    self->currentEntry = _firstEntry;
    self->count        = _count;
    return self;
}

- (void)dealloc {
    RELEASE(self->dict);
    [super dealloc];
}

- (id)nextObject {
  if (self->count > 0) {
        id obj;
        obj = self->currentEntry->key;
        self->currentEntry++;
        self->count--;
        return obj;
  }
    
  return nil;
}

@end /* _NSConcreteSmallDictionaryKeyEnumerator */
