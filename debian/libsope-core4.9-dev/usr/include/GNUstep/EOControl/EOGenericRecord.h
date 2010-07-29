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

#ifndef __EOControl_EOGenericRecord_h__
#define __EOControl_EOGenericRecord_h__

#import <Foundation/NSObject.h>
#import <Foundation/NSMapTable.h>
#include <EOControl/EOGlobalID.h>

@class NSDictionary, NSArray, NSString, NSEnumerator;
@class EOClassDescription;

/*
 * EOGeneric record class, used for enterprise objects
 * that do not have special data handling
 */

@interface EOGenericRecord : NSObject < NSCopying >
{
  EOClassDescription *classDescription;
  IMP                willChange;

  /* hash-table */
  struct _NSMapNode  **nodes;
  unsigned int       hashSize;
  unsigned int       itemsCount;
}

- (id)initWithEditingContext:(id)_ec
  classDescription:(EOClassDescription *)_classDesc
  globalID:(EOGlobalID *)_oid;

// Key-value coding methods

- (void)takeValuesFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)valuesForKeys:(NSArray *)keys;

// Shortcuts to key-value coding methods

- (void)setObject:(id)anObject forKey:(id)aKey;
- (id)objectForKey:(id)aKey;
- (void)removeObjectForKey:(id)aKey;

@end /* EOGenericRecord */


@class NSEnumerator;

@interface EOGenericRecord(EOMOF2Extensions)
- (NSEnumerator *)keyEnumerator;
@end

#endif /* __EOControl_EOGenericRecord_h__ */
