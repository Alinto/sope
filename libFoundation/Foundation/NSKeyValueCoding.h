/* 
   NSKeyValueCoding.h

   Copyright (C) 2000, MDlink online service center GmbH, Helge Hess
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

#ifndef __NSKeyValueCoding_h__
#define __NSKeyValueCoding_h__

#include <Foundation/NSObject.h>

@interface NSObject(NSKeyValueCoding)

/* settings */

+ (BOOL)accessInstanceVariablesDirectly;
+ (BOOL)useStoredAccessor;

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key;
- (id)valueForKey:(NSString *)_key;

/* stored values */

- (void)takeStoredValue:(id)_value forKey:(NSString *)_key;
- (id)storedValueForKey:(NSString *)_key;

@end

@interface NSObject(KeyPaths)

- (void)takeValue:(id)_value forKeyPath:(NSString *)_keyPath;
- (id)valueForKeyPath:(NSString *)_keyPath;

@end

@class NSArray, NSDictionary;

@interface NSObject(KeySets)

- (void)takeValuesFromDictionary:(NSDictionary *)_dictionary;
- (NSDictionary *)valuesForKeys:(NSArray *)_keys;

@end

@interface NSObject(NSKeyValueCodingErrorHandling)

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key;
- (id)handleQueryWithUnboundKey:(NSString *)_key;
- (void)unableToSetNullForKey:(NSString *)_key;

@end

#endif /* __NSKeyValueCoding_h__ */
