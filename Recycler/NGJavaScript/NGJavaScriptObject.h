/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

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
// $Id$

#ifndef __NGJavaScriptObject_H__
#define __NGJavaScriptObject_H__

#import <Foundation/NSObject.h>
#include "NSObject+JS.h"

/*
  NGJavaScriptObject
  
  Related: NGJavaScriptObjectHandler, see docu
  
  Hm, what is the difference between the handler and the object ?
  => find out and document
  
  Note: this object keeps a retained reference to the context.
*/

@class NSEnumerator, NSArray, NSString, NSDictionary;
@class NGObjectMappingContext;
@class NGJavaScriptObjectMappingContext;

@interface NGJavaScriptObject : NSObject < NSCoding >
{
  NGJavaScriptObjectMappingContext *ctx;
  void *jscx;     /* cached JSContext handle         */
  void *handle;   /* the handle of the object itself */
  BOOL addedRoot; /* was a root-ref added            */
}

- (id)initWithHandle:(void *)_handle
  inMappingContext:(NGObjectMappingContext *)_ctx;

/* private */

- (void *)handle;
- (void)makeGlobal;
- (void *)_jsHandleInMapContext:(NGObjectMappingContext *)_ctx;

/* misc */

- (void)applyStandardClasses;

- (void)setParentObject:(id)_parent;
- (id)parentObject;
- (NSEnumerator *)parentObjectChain;

- (void)setPrototypeObject:(id)_proto;
- (id)prototypeObject;
- (NSEnumerator *)prototypeObjectChain;

- (BOOL)hasPropertyNamed:(NSString *)_key;
- (BOOL)hasFunctionNamed:(NSString *)_key;

/* a function object */

- (BOOL)isJavaScriptFunction;
- (id)callOn:(id)_this;
- (id)callOn:(id)_this withObject:(id)_arg0;

/* mimic an NSDictionary */

- (void)setObject:(id)_value forKey:(id)_key;
- (id)objectForKey:(id)_key;
- (void)removeObjectForKey:(id)_key;
- (NSEnumerator *)keyEnumerator;
- (NSEnumerator *)objectEnumerator;
- (NSArray *)allKeys;
- (NSArray *)allValues;

/* convert to dictionary */

- (NSDictionary *)convertToNSDictionary;

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key;
- (id)valueForKey:(NSString *)_key;

@end

#import <Foundation/NSArray.h>

/* this class gets the NSMutableArray behaviour added !!! */

@interface NGJavaScriptArray : NGJavaScriptObject < NSCopying >

/* convert to array */

- (NSArray *)convertToNSArray;

@end

@interface NGJavaScriptArray(NSArrayCompatibility)

- (unsigned)count;
- (id)objectAtIndex:(unsigned)_idx;
- (NSEnumerator *)objectEnumerator;
- (id)lastObject;

- (NSArray *)arrayByAddingObject:(id)anObject;
- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)anotherArray;

- (NSArray *)sortedArrayUsingFunction:
  (int(*)(id element1, id element2, void *userData))comparator
  context:(void*)context;

@end

@interface NGJavaScriptArray(NSMutableArrayCompatibility)

- (void)setObject:(id)_obj atIndex:(unsigned)_idx;

- (void)removeObjectsInRange:(NSRange)aRange;
- (void)removeAllObjects;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(unsigned)_idx;

- (void)insertObject:(id)_object atIndex:(unsigned)_idx;
- (void)addObject:(id)_object;

@end

#endif /* __NGJavaScriptObject_H__ */
