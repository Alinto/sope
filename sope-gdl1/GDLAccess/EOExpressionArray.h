/* 
   EOExpressionArray.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: September 1996

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

#ifndef __EOExpressionArray_h__
#define __EOExpressionArray_h__

#import <Foundation/NSString.h>

@class EOAttribute, EOEntity, EOExpressionArray;

@protocol EOExpressionContext <NSObject>

- (NSString *)expressionValueForAttribute:(EOAttribute *)anAttribute;
- (NSString *)expressionValueForAttributePath:(NSArray *)path;

@end

/*
  Notes
  
  In LSExtendedSearchCommand this is bound to the 'content' of EOSQLQualifier
  and contains an array like:

    "(", "(", "(", LOWER, "(", { allowsNull=Y; columnName=name; width=50;...},
    ...
    " = ", 0, ")", ")"

  so it seems to be a stream of tokens and an EOAttribute mixed in for column
  keys.
  
  Apparently only EOSQLExpression supports the 'EOExpressionContext'?
*/

@interface EOExpressionArray : NSObject < NSMutableCopying >
{
@protected
    NSMutableArray *array;
    NSString       *prefix;
    NSString       *infix;
    NSString       *suffix;
}

/* Initializing instances */
- (id)initWithPrefix:(NSString*)prefix
  infix:(NSString*)infix
  suffix:(NSString*)suffix;

/* Accessing the components */
- (void)setPrefix:(NSString*)prefix;
- (NSString*)prefix;
- (void)setInfix:(NSString*)infix;
- (NSString*)infix;
- (void)setSuffix:(NSString*)suffix;
- (NSString*)suffix;

/* Checking contents */
- (BOOL)referencesObject:(id)anObject;

- (NSString *)expressionValueForContext:(id<EOExpressionContext>)ctx;

+ (EOExpressionArray *)parseExpression:(NSString *)expression
	entity:(EOEntity *)entity
	replacePropertyReferences:(BOOL)flag;

+ (EOExpressionArray *)parseExpression:(NSString *)expression
	entity:(EOEntity *)entity
	replacePropertyReferences:(BOOL)flag
        relationshipPaths:(NSMutableArray *)relationshipPaths;

// array compatibility

- (void)addObjectsFromExpressionArray:(EOExpressionArray *)_array;

- (void)insertObject:(id)_obj atIndex:(unsigned int)_idx;
- (void)addObjectsFromArray:(NSArray *)_array;
- (void)addObject:(id)_object;
- (unsigned int)indexOfObject:(id)_object;
- (id)objectAtIndex:(unsigned int)_idx;
- (id)lastObject;
- (NSUInteger)count;
- (NSEnumerator *)objectEnumerator;
- (NSEnumerator *)reverseObjectEnumerator;

@end /* EOExpressionArray */


@interface NSObject (EOExpression)
- (NSString *)expressionValueForContext:(id<EOExpressionContext>)context;
@end

#endif /* __EOExpressionArray_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
