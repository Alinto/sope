/* 
   EOPrimaryKeyDictionary.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

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

#import "common.h"
#import "EOPrimaryKeyDictionary.h"
#import <EOControl/EONull.h>

/*
 * Concrete Classes declaration
 */

@interface EOSinglePrimaryKeyDictionary : EOPrimaryKeyDictionary
{
  id key;
  id value;
}
- (id)initWithObject:(id)anObject forKey:(id)aKey;
- (id)key;
@end

@interface EOSinglePrimaryKeyDictionaryEnumerator : NSEnumerator
{
    id key;
}

- (id)iniWithObject:(id)_key;

@end

@interface EOMultiplePrimaryKeyDictionary : EOPrimaryKeyDictionary
{
  int     count;
  NSArray *keys;
  id      values[0];
}

+ (id)allocWithZone:(NSZone *)_zone capacity:(int)_capacity;
- (id)initWithKeys:(NSArray *)_keys fromDictionary:(NSDictionary *)_dict;

@end

/*
 * Single key dictionary 
 */

@implementation EOSinglePrimaryKeyDictionary

- (id)initWithObject:(id)_object forKey:(id)_key {
  NSAssert(_key,     @"provided invalid key (is nil)");
  NSAssert1(_object, @"provided invalid value (is nil), key=%@", _key);

  if ([_object isKindOfClass:[EONull class]]) {
    NSLog(@"value of primary key %@ is null ..", _key);
    RELEASE(self);
    return nil;
  }
  
  NSAssert(![_object isKindOfClass:[EONull class]],
           @"value of primary key may not be null !");
  
  self->key      = RETAIN(_key);
  self->value    = RETAIN(_object);
  self->fastHash = [_object hash];
  return self;
}

- (void)dealloc {
    RELEASE(self->key);
    RELEASE(self->value);
    [super dealloc];
}

/* operations */

- (NSEnumerator *)keyEnumerator {
    return AUTORELEASE([[EOSinglePrimaryKeyDictionaryEnumerator alloc]
                           iniWithObject:self->key]);
}

- (id)objectForKey:(id)_key {
    return [key isEqual:_key] ? value : nil;
}

- (unsigned int)count {
    return 1;
}
- (BOOL)isNotEmpty {
  return YES;
}

- (NSUInteger)hash {
    return 1;
}

- (id)key {
    return self->key;
}

- (NSArray *)allKeys {
    return [NSArray arrayWithObject:key];
}

- (NSArray *)allValues {
    return [NSArray arrayWithObject:value];
}

- (BOOL)isEqualToDictionary:(NSDictionary *)other {
    if (self == (EOSinglePrimaryKeyDictionary*)other)
        return YES;
    if (self->isa == ((EOSinglePrimaryKeyDictionary*)other)->isa) {
        if (fastHash == ((EOSinglePrimaryKeyDictionary*)other)->fastHash &&
            [key isEqual:((EOSinglePrimaryKeyDictionary*)other)->key] &&
            [value isEqual:((EOSinglePrimaryKeyDictionary*)other)->value])
                return YES;
        else
                return NO;
    }
    if ([other count] != 1)
        return NO;
    return [value isEqual:[other objectForKey:key]];
}

- (id)copyWithZone:(NSZone*)zone {
    if ([self zone] == (zone ? zone : NSDefaultMallocZone()))
        return RETAIN(self);
    else
        return [[[self class] allocWithZone:zone] 
                   initWithObject:value forKey:key];
}
- (id)copy {
    return [self copyWithZone:NULL];
}

- (BOOL)fastIsEqual:(id)other {
    if (self == other)
        return YES;
    if (self->isa == ((EOSinglePrimaryKeyDictionary*)other)->isa) {
        if (fastHash == ((EOSinglePrimaryKeyDictionary*)other)->fastHash &&
            key == ((EOSinglePrimaryKeyDictionary*)other)->key &&
            [value isEqual:((EOSinglePrimaryKeyDictionary*)other)->value])
                return YES;
        else
            return NO;
    }
    [NSException raise:NSInvalidArgumentException
		 format:
		   @"fastIsEqual: compares only "
		   @"EOPrimaryKeyDictionary instances !"];
    return NO;
}

@end /* EOSinglePrimaryKeyDictionary */

@implementation EOSinglePrimaryKeyDictionaryEnumerator

- (id)iniWithObject:(id)aKey {
    self->key = RETAIN(aKey);
    return self;
}

- (void)dealloc {
    RELEASE(self->key);
    [super dealloc];
}

/* operations */

- (id)nextObject {
    id tmp = self->key;
    self->key = nil;
    return AUTORELEASE(tmp);
}

@end /* EOSinglePrimaryKeyDictionaryEnumerator */

/*
 * Multiple key dictionary is very time-memory efficient
 */

@implementation EOMultiplePrimaryKeyDictionary

+ (id)allocWithZone:(NSZone *)zone capacity:(int)capacity {
    return NSAllocateObject(self, sizeof(id)*capacity, zone);
}

- (id)initWithKeys:(NSArray*)theKeys fromDictionary:(NSDictionary*)dict; {
    int i;
    
    self->count    = [theKeys count];
    self->keys     = RETAIN(theKeys);
    self->fastHash = 0;
    
    for (i = 0; i < count; i++) {
        self->values[i] = [dict objectForKey:[keys objectAtIndex:i]];
        RETAIN(self->values[i]);

        NSAssert(![values[i] isKindOfClass:[EONull class]],
                 @"primary key values may not be null !");
        
        if (self->values[i] == nil) {
            AUTORELEASE(self);
            return nil;
        }
        self->fastHash += [self->values[i] hash];
    }
    
    return self;
}

- (void)dealloc {
    int i;
    
    for (i = 0; i < count; i++)
        RELEASE(self->values[i]);
    RELEASE(self->keys);
    [super dealloc];
}

/* operations */

- (NSEnumerator *)keyEnumerator {
    return [self->keys objectEnumerator];
}

- (id)objectForKey:(id)aKey {
    int max, min, mid;
    // Binary search for key's index
    for (min = 0, max = count-1; min <= max; ) {
        NSComparisonResult ord;
        
        mid = (min+max) >> 1;
        ord = [(NSString*)aKey compare:(NSString*)[keys objectAtIndex:mid]];
        if (ord == NSOrderedSame)
            return values[mid];
        if (ord == NSOrderedDescending) 
            min = mid+1;
        else
            max = mid-1;
    }
    return nil;
}

- (unsigned int)count {
    return self->count;
}
- (BOOL)isNotEmpty {
  return self->count > 0 ? YES : NO;
}

- (unsigned int)hash {
    return self->count;
}

- (NSArray *)allKeys {
    return self->keys;
}

- (NSArray *)allValues {
    return AUTORELEASE([[NSArray alloc] initWithObjects:values count:count]);
}

- (BOOL)isEqualToDictionary:(NSDictionary *)other {
    int i;
    
    if (self == (EOMultiplePrimaryKeyDictionary*)other)
        return YES;
    if ((unsigned)self->count != [other count])
        return NO;
    for (i = 0; i < self->count; i++) {
        if (![values[i] isEqual:[other objectForKey:[keys objectAtIndex:i]]])
            return NO;
    }
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    if ([self zone] == (zone ? zone : NSDefaultMallocZone()))
        return RETAIN(self);
    else {
        return [[[self class]
                       allocWithZone:zone capacity:count] 
                       initWithKeys:keys fromDictionary:self];
    }
}
- (id)copy {
    return [self copyWithZone:NULL];
}

- (unsigned)fastHash {
    return self->fastHash;
}

- (BOOL)fastIsEqual:(id)aDict {
    int i;
    
    if (self->isa != ((EOMultiplePrimaryKeyDictionary*)aDict)->isa) {
      [NSException raise:NSInvalidArgumentException
		   format:@"fastIsEqual: can compare only "
                           @"EOPrimaryKeyDictionary instances"];
    }
    if (self->count != ((EOMultiplePrimaryKeyDictionary*)aDict)->count ||
        self->fastHash != ((EOMultiplePrimaryKeyDictionary*)aDict)->fastHash ||
        self->keys != ((EOMultiplePrimaryKeyDictionary*)aDict)->keys)
        return NO;
    
    for (i = count - 1; i >= 0; i--) {
      if (![values[i] isEqual:
            ((EOMultiplePrimaryKeyDictionary*)aDict)->values[i]])
	return NO;
    }
    return YES;
}

@end /* EOMultiplePrimaryKeyDictionary */

/*
 * Cluster Abstract class
 */

@implementation EOPrimaryKeyDictionary

+ (id)allocWithZone:(NSZone *)_zone {
  return NSAllocateObject(self, 0, _zone);
}

+ (id)dictionaryWithKeys:(NSArray *)keys fromDictionary:(NSDictionary *)dict {
    if ([dict count] == 0)
        return nil;
    
    if ([keys count] == 1) {
        id key      = [keys objectAtIndex:0];
        id keyValue = [dict objectForKey:key];
        
        NSAssert2(keyValue, @"dictionary %@ contained no value for key %@ ..",
                  dict, key);
        
        // Check if already an EOSinglePrimaryKeyDictionary from same entity
        // return it since the new one will be identical to it; we have
        // no problem regarding its correctness since it was built by this
        // method !
        if ([dict isKindOfClass:[EOSinglePrimaryKeyDictionary class]]) {
          if ([(EOSinglePrimaryKeyDictionary*)dict key]==key)
            return dict;
        }
	
        //HH:
        // Check if the keyValue is EONull. If this is the case, return nil.
        // Primary keys are always 'not null'.
        if ([keyValue isKindOfClass:[EONull class]])
          return nil;
        
        // Alloc single key dictionary
        return AUTORELEASE([[EOSinglePrimaryKeyDictionary alloc]
                                                          initWithObject:keyValue
                                                          forKey:key]);
    }
    else {
        // Check if already an EOMultiplePrimaryKeyDictionary from same entity
        // return it since the new one will be identical to it; we have
        // no problem regarding its correctness since it was built by this
        // method !
        if ([dict isKindOfClass:[EOMultiplePrimaryKeyDictionary class]] &&
            [dict allKeys] == keys)
                return dict;
        // Alloc multi-key dictionary
        return AUTORELEASE([[EOMultiplePrimaryKeyDictionary 
                                allocWithZone:NULL capacity:[keys count]]
                               initWithKeys:keys fromDictionary:dict]);
    }
}

+ (id)dictionaryWithObject:(id)object forKey:(id)key {
    return AUTORELEASE([[EOSinglePrimaryKeyDictionary alloc]
                           initWithObject:object forKey:key]);
}

- (unsigned)fastHash {
    return self->fastHash;
}

- (BOOL)fastIsEqual:aDict {
    // TODO - request concrete implementation
    return NO;
}

@end /* EOPrimaryKeyDictionary */
