/* 
   NSExpression.h

   Copyright (C) 2005, Helge Hess
   All rights reserved.

   Author: Helge Hess <helge.hess@opengroupware.org>

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

#ifndef __NSExpression_H__
#define __NSExpression_H__

#include <Foundation/NSObject.h>

typedef enum {
    NSConstantValueExpressionType = 0,
    NSEvaluatedObjectExpressionType,
    NSVariableExpressionType,
    NSKeyPathExpressionType,
    NSFunctionExpressionType
} NSExpressionType;

@class NSString, NSArray, NSMutableDictionary;

@interface NSExpression : NSObject < NSCoding, NSCopying >

+ (NSExpression *)expressionForConstantValue:(id)_value;
+ (NSExpression *)expressionForEvaluatedObject;
+ (NSExpression *)expressionForFunction:(NSString *)_f arguments:(NSArray *)_a;
+ (NSExpression *)expressionForKeyPath:(NSString *)_keyPath;
+ (NSExpression *)expressionForVariable:(NSString *)_varName;

- (id)initWithExpressionType:(NSExpressionType)_type;

/* accessors */

- (id)constantValue;
- (NSExpressionType)expressionType;

- (NSString *)keyPath;
- (NSExpression *)operand;
- (NSString *)function;
- (NSString *)variable;
- (NSArray *)arguments;

/* evaluation */

- (id)expressionValueWithObject:(id)_object context:(NSMutableDictionary *)_cx;

@end

#endif /* __NSExpression_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
