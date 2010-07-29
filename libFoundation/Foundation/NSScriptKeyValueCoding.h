/* 
   NSScriptKeyValueCoding.h

   Copyright (C) 2002, SKYRIX Software AG, Helge Hess
   All rights reserved.
   
   Author: Helge Hess <helge.hess@skyrix.com>

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

#ifndef __NSScriptKeyValueCoding_h__
#define __NSKeyValueCoding_h__

#include <Foundation/NSObject.h>

@interface NSObject(NSScriptKeyValueCoding)

/* type coercion */

- (id)coerceValue:(id)_val forKey:(NSString *)_key;

/* query array properties (toManyRelationshipKeys) */

- (id)valueAtIndex:(unsigned)_idx     inPropertyWithKey:(NSString *)_key;
- (id)valueWithName:(NSString *)_name inPropertyWithKey:(NSString *)_key;
- (id)valueWithUniqueID:(id)_uid      inPropertyWithKey:(NSString *)_key;

/* modifying array properties (toManyRelationshipKeys) */

- (void)insertValue:(id)_val atIndex:(unsigned)_idx
  inPropertyWithKey:(NSString *)_key;
- (void)insertValue:(id)_val inPropertyWithKey:(NSString *)_key;

- (void)removeValueAtIndex:(unsigned)_idx fromPropertyWithKey:(NSString *)_key;

- (void)replaceValueAtIndex:(unsigned)_idx inPropertyWithKey:(NSString *)_key
  withValue:(id)_val;

@end

#endif /* __NSScriptKeyValueCoding_h__ */
