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

#ifndef __EOControl_EOKeyValueCoding_H__
#define __EOControl_EOKeyValueCoding_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>

#if NeXT_Foundation_LIBRARY

#import <Foundation/NSKeyValueCoding.h>

#else

@interface NSObject(EOKeyValueCoding)

+ (BOOL)accessInstanceVariablesDirectly;
+ (void)flushAllKeyBindings;

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key;
- (id)handleQueryWithUnboundKey:(NSString *)_key;
- (void)unableToSetNullForKey:(NSString *)_key;

- (void)takeValuesFromDictionary:(NSDictionary *)_dictionary;
- (NSDictionary *)valuesForKeys:(NSArray *)_keys;

- (void)takeValue:(id)_value forKey:(NSString *)_key;
- (id)valueForKey:(NSString *)_key;

/* stored values */

+ (BOOL)useStoredAccessor;
- (void)takeStoredValue:(id)_value forKey:(NSString *)_key;
- (id)storedValueForKey:(NSString *)_key;

@end

/* key-path stuff */

@interface NSObject(EOKeyPathValueCoding)

- (void)takeValue:(id)_value forKeyPath:(NSString *)_keyPath;
- (id)valueForKeyPath:(NSString *)_keyPath;

@end

/* array stuff */

@interface NSArray(EOKeyValueCoding)

/*
  Special functions for computed values. Computed keys start with
  '@', seg '@sum'. Yoy can define own computed keys by following the
  method naming 'compute' + Func + 'ForKey:'.
*/
- (id)computeSumForKey:(NSString *)_key;
- (id)computeAvgForKey:(NSString *)_key;
- (id)computeCountForKey:(NSString *)_key;
- (id)computeMaxForKey:(NSString *)_key;
- (id)computeMinForKey:(NSString *)_key;

/*
  Attention: NSArray's 'valueForKey:' is special in that it does not
  return properties of the array but an array of the properties of it's
  elements. That is, it is similiar to a map function.
*/
- (id)valueForKey:(NSString *)_key;

@end

#endif /* !NeXT_Foundation_LIBRARY */

#endif /* __EOControl_EOKeyValueCoding_H__ */
