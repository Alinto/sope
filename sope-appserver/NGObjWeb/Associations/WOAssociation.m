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

#include <NGObjWeb/WOAssociation.h>
#include "WOValueAssociation.h"
#include "WOKeyPathAssociation.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOContext.h>
#include "common.h"

@interface WOContext(Cursor)
- (id)cursor;
@end

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY || \
    COCOA_Foundation_LIBRARY
@interface NSObject(Missing)
- (void)subclassResponsibility:(SEL)cmd;
- (void)notImplemented:(SEL)cmd;
@end
#endif

@implementation WOAssociation

static Class WOKeyPathAssociationClass = Nil;

+ (int)version {
  return 2;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *s;
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  s = [ud stringForKey:@"WOKeyPathAssociationClass"];
  if ([s length] > 0) {
#if DEBUG
    NSLog(@"Note: using different class for keypath associations: %@", s);
#endif
    WOKeyPathAssociationClass = NSClassFromString(s);
  }
  if (WOKeyPathAssociationClass == Nil)
    WOKeyPathAssociationClass = [WOKeyPathAssociation class];
}

+ (WOAssociation *)associationWithKeyPath:(NSString *)_keyPath {
  static int WOCacheKeyPathAssociations = -1;
  static NSMapTable *cache = NULL;
  static unsigned cacheHits   = 0;
  static unsigned cacheMisses = 0;
  WOAssociation *a;
  
  if (WOCacheKeyPathAssociations == -1) {
    WOCacheKeyPathAssociations =
      [[[NSUserDefaults standardUserDefaults]
                        objectForKey:@"WOKeyPathAssociationsCacheSize"]
                        intValue];
    if (WOCacheKeyPathAssociations > 0) {
      cache = NSCreateMapTable(NSObjectMapKeyCallBacks,
                               NSObjectMapValueCallBacks,
                               WOCacheKeyPathAssociations);
    }
  }

  if (cache) {
    if ((a = NSMapGet(cache, _keyPath))) {
      cacheHits++;
#if 0 && DEBUG
      printf("%s: cache hits: %d, misses: %d, size:%d\n",
             __PRETTY_FUNCTION__,
             cacheHits, cacheMisses, NSCountMapTable(cache));
#endif
      return [[a retain] autorelease];
    }
    
    cacheMisses++;
    
    if (cacheMisses > 1000) {
      if (cacheHits < cacheMisses) {
        fprintf(stderr,
                "%s: disabling association cache "
                "(%d cache misses vs %d cache hits)\n",
                __PRETTY_FUNCTION__, cacheMisses, cacheHits);
        if (cache) NSFreeMapTable(cache);
        cache = NULL;
      }
    }
  }
  
  a = [[WOKeyPathAssociationClass alloc] initWithKeyPath:_keyPath];
  
  if (cache)
    NSMapInsert(cache, _keyPath, a);
  
  return [a autorelease];
}
+ (WOAssociation *)associationWithValue:(id)_value {
  static int        WOCacheValueAssociations   = -1;
  static NSMapTable *cache = NULL;
  static unsigned   cacheHits   = 0;
  static unsigned   cacheMisses = 0;
  static NSNumber   *boolYes    = nil;
  static NSNumber   *boolNo     = nil;
  WOAssociation *a;
  
  if (_value == nil) return nil;
  
  if (boolYes == nil)
    boolYes = [[NSNumber numberWithBool:YES] retain];
  if (boolNo == nil)
    boolNo = [[NSNumber numberWithBool:NO] retain];
  
  if (boolYes == _value) {
    static WOAssociation *yesAssoc = nil;
    
    if (yesAssoc == nil)
      yesAssoc = [[_WOBoolValueAssociation associationWithBool:YES] retain];
    
    return yesAssoc;
  }
  if (boolNo == _value) {
    static WOAssociation *noAssoc = nil;
    
    if (noAssoc == nil)
      noAssoc = [[_WOBoolValueAssociation associationWithBool:NO] retain];
    
    return noAssoc;
  }
  
  if (![_value conformsToProtocol:@protocol(NSCopying)])
    /* if the value can't be copied, it shouldn't be cached ! */
    return [WOValueAssociation associationWithValue:_value];
  
  _value = [[_value copyWithZone:NULL] autorelease];
  
  if (WOCacheValueAssociations == -1) {
    WOCacheValueAssociations =
      [[[NSUserDefaults standardUserDefaults]
                        objectForKey:@"WOValueAssociationsCacheSize"]
                        intValue];
    if (WOCacheValueAssociations > 0) {
      cache = NSCreateMapTable(NSObjectMapKeyCallBacks,
                               NSObjectMapValueCallBacks,
                               WOCacheValueAssociations);
    }
  }

  if (cache) {
    if ((a = NSMapGet(cache, _value))) {
      cacheHits++;
#if 0 && DEBUG
      printf("%s: cache hits: %d, misses: %d, size:%d\n",
             __PRETTY_FUNCTION__,
             cacheHits, cacheMisses, NSCountMapTable(cache));
#endif
      return [[a retain] autorelease];
    }
    
    cacheMisses++;
    
    if (cacheMisses > 1000) {
      if (cacheHits < cacheMisses) {
        fprintf(stderr,
                "%s: disabling association cache "
                "(%d cache misses vs %d cache hits)",
                __PRETTY_FUNCTION__, cacheMisses, cacheHits);
        if (cache) NSFreeMapTable(cache);
        cache = NULL;
      }
    }
  }
  
  a = [WOValueAssociation associationWithValue:_value];
  
  if (cache != NULL)
    NSMapInsert(cache, _value, a);
  
  return a;
}

/* value */

- (void)setValue:(id)_value {
  IS_DEPRECATED;
  [self setValue:_value
        inComponent:[[[WOApplication application] context] component]];
}
- (id)value {
  IS_DEPRECATED;
  return [self valueInComponent:
                 [[[WOApplication application] context] component]];
}

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  [self subclassResponsibility:_cmd];
}
- (id)valueInComponent:(WOComponent *)_component {
  [self subclassResponsibility:_cmd];
  return nil;
}

- (void)setValue:(id)_value inContext:(WOContext *)_ctx {
  [self setValue:_value inComponent:(id)[_ctx cursor]];
}
- (id)valueInContext:(WOContext *)_ctx {
  return [self valueInComponent:(id)[_ctx cursor]];
}

- (BOOL)isValueConstant {
  [self subclassResponsibility:_cmd];
  return NO;
}
- (BOOL)isValueSettable {
  [self subclassResponsibility:_cmd];
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]>", 
                   self, NSStringFromClass([self class])];
}

/* special values */

- (void)setUnsignedCharValue:(unsigned char)_v inComponent:(WOComponent *)_c {
  [self setValue:[NSNumber numberWithUnsignedChar:_v] inComponent:_c];
}
- (void)setCharValue:(signed char)_val inComponent:(WOComponent *)_component {
  [self setValue:[NSNumber numberWithChar:_val] inComponent:_component];
}
- (void)setUnsignedIntValue:(unsigned int)_v inComponent:(WOComponent *)_c {
  [self setValue:[NSNumber numberWithUnsignedInt:_v] inComponent:_c];
}
- (void)setIntValue:(signed int)_value inComponent:(WOComponent *)_component {
  [self setValue:[NSNumber numberWithInt:_value] inComponent:_component];
}
- (void)setBoolValue:(BOOL)_value inComponent:(WOComponent *)_component {
  [self setValue:[NSNumber numberWithBool:_value] inComponent:_component];
}

- (unsigned char)unsignedCharValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] unsignedCharValue];
}
- (signed char)charValueInComponent:(WOComponent *)_component {
  return [(id<NGBaseTypeValues>)[self valueInComponent:_component] charValue];
}
- (unsigned int)unsignedIntValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] unsignedIntValue];
}
- (signed int)intValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] intValue];
}
- (BOOL)boolValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] boolValue];
}

- (void)setStringValue:(NSString *)_v inComponent:(WOComponent *)_component {
  [self setValue:_v inComponent:_component];
}
- (NSString *)stringValueInComponent:(WOComponent *)_component {
  return [[self valueInComponent:_component] stringValue];
}

/* special context values */

- (void)setUnsignedCharValue:(unsigned char)_v inContext:(WOContext *)_c {
  [self setUnsignedCharValue:_v inComponent:(id)[_c cursor]];
}
- (void)setCharValue:(signed char)_value inContext:(WOContext *)_ctx {
  [self setCharValue:_value inComponent:(id)[_ctx cursor]];
}
- (void)setUnsignedIntValue:(unsigned int)_v inContext:(WOContext *)_c {
  [self setUnsignedIntValue:_v inComponent:(id)[_c cursor]];
}
- (void)setIntValue:(signed int)_value inContext:(WOContext *)_ctx {
  [self setIntValue:_value inComponent:(id)[_ctx cursor]];
}
- (void)setBoolValue:(BOOL)_value inContext:(WOContext *)_ctx {
  [self setBoolValue:_value inComponent:(id)[_ctx cursor]];
}

- (unsigned char)unsignedCharValueInContext:(WOContext *)_ctx {
  return [self unsignedCharValueInComponent:[_ctx cursor]];
}
- (signed char)charValueInContext:(WOContext *)_ctx {
  return [self charValueInComponent:[_ctx cursor]];
}
- (unsigned int)unsignedIntValueInContext:(WOContext *)_ctx {
  return [self unsignedIntValueInComponent:[_ctx cursor]];
}
- (signed int)intValueInContext:(WOContext *)_ctx {
  return [self intValueInComponent:[_ctx cursor]];
}
- (BOOL)boolValueInContext:(WOContext *)_ctx {
  return [self boolValueInComponent:[_ctx cursor]];
}

- (void)setStringValue:(NSString *)_v inContext:(WOContext *)_ctx {
  [self setValue:_v inComponent:[_ctx cursor]];
}
- (NSString *)stringValueInContext:(WOContext *)_ctx {
  return [[self valueInComponent:(id)[_ctx cursor]] stringValue];
}

/* copying */

- (id)copyWithZone:(NSZone *)_zone {
  // WOAssociations are immutable
  return [self retain];
}

/* BugTrap */

- (unsigned int)unsignedIntValue {
  [self notImplemented:_cmd];
  return 0;
}
- (signed int)intValue {
  [self notImplemented:_cmd];
  return 0;
}
- (float)floatValue {
  [self notImplemented:_cmd];
  return 0.0;
}
- (BOOL)boolValue {
  [self notImplemented:_cmd];
  return NO;
}

- (NSString *)stringValue {
  [self notImplemented:_cmd];
  return nil;
}

@end /* WOAssociation */
