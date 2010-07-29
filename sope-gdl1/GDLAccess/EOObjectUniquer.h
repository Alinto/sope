/* 
   EOObjectUniquer.h

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

#ifndef __EOObjectUniquer_h__
#define __EOObjectUniquer_h__

#import <Foundation/NSObject.h>
#import <Foundation/NSMapTable.h>

@class EOEntity;
@class NSDictionary;
@class NSArray;

typedef struct _EOUniquerRecord {
    int refCount;
    id	pkey;
    id	entity;
    id	object;
    id	snapshot;
} EOUniquerRecord;

@interface EOObjectUniquer : NSObject
{
@protected
    NSMapTable              *primaryKeyToRec;
    NSMapTable              *objectsToRec;
    struct _EOUniquerRecord *keyRecord;
}

// Initializing a uniquing dictionary
- init;

// Transfer self to parent
- (void)transferTo:(EOObjectUniquer*)dest
  objects:(BOOL)isObj andSnapshots:(BOOL)isSnap;

// Handling objects
- (void)forgetObject:(id)anObj;
- (void)forgetAllObjects;
- (void)forgetAllSnapshots;

- (id)objectForPrimaryKey:(NSDictionary *)aKey
  entity:(EOEntity *)anEntity;

- (EOUniquerRecord *)recordForObject:(id)anObj;

- (void)recordObject:(id)anObj
  primaryKey:(NSDictionary *)aKey
  entity:(EOEntity *)anEntity
  snapshot:(NSDictionary *)aSnapshot;

@end /* EOObjectUniquer */

#endif /* __EOObjectUniquer_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
