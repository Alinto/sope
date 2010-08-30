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

#ifndef __NGExtensions_NGStack_H__
#define __NGExtensions_NGStack_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>
#import <Foundation/NSArray.h>

@class NSArray;

@protocol NGStack < NSObject >

// state

- (NSUInteger)stackPointer;
- (NSUInteger)count;
- (BOOL)isEmpty;

// operations

- (void)push:(id)_obj;
- (id)pop;
- (void)clear;

// elements

- (id)elementAtTop;
- (NSEnumerator *)topDownEnumerator;
- (NSEnumerator *)bottomUpEnumerator;

@end

@interface NGStack : NSObject < NGStack, NSCoding, NSCopying >
{
@protected
  unsigned int stackPointer;
  unsigned int capacity;
  id           *stack;
}

+ (id)stackWithCapacity:(NSUInteger)_capacity;
+ (id)stack;
+ (id)stackWithArray:(NSArray *)_array;
- (id)init;
- (id)initWithCapacity:(NSUInteger)_capacity; // designated initializer
- (id)initWithArray:(NSArray *)_array;

// state

- (NSUInteger)capacity;

- (NSUInteger)stackPointer;
- (NSUInteger)count;
- (BOOL)isEmpty;

// elements

- (id)elementAtTop;
- (id)elementAtBottom;
- (NSEnumerator *)topDownEnumerator;
- (NSEnumerator *)bottomUpEnumerator;

// operations

- (void)push:(id)_obj;
- (id)pop;
- (void)clear;

// description

- (NSArray *)toArray; // array representation, bottom element first

@end

@interface NGStackException : NSException
@end

@interface NSMutableArray(Stack) < NGStack >
@end

#endif /* __NGExtensions_NGStack_H__ */
