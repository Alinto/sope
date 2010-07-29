/* 
   EOQuotedExpression.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
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

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import "common.h"
#import "EOQuotedExpression.h"

@implementation EOQuotedExpression

- (id)expressionValueForContext:(id<EOExpressionContext>)_context {
  NSMutableString *result;
  NSArray         *components;
  id              expr;

  expr       = [(EOExpressionArray *)self->expression 
				     expressionValueForContext:_context];
  components = [expr componentsSeparatedByString:quote];
  result     = [NSMutableString stringWithCapacity:[expr length] + 10];

  [result appendString:quote];
  [result appendString:[components componentsJoinedByString:escape]];
  [result appendString:quote];
  
  return result;
}

- (id)initWithExpression:(id)_expression
  quote:(NSString *)_quote
  escape:(NSString *)_escape
{
  if ((self = [super init])) {
    ASSIGN(self->expression, _expression);
    ASSIGN(self->quote, _quote);
    ASSIGN(self->escape, _escape);
  }

  return self;
}

- (void)dealloc {
  RELEASE(self->expression);
  RELEASE(self->quote);
  RELEASE(self->escape);
  [super dealloc];
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone {
    return [[[self class]
                   allocWithZone:zone]
                   initWithExpression:expression quote:quote escape:escape];
}
- (id)copy {
    return [self copyWithZone:NSDefaultMallocZone()];
}

@end /* EOQuotedExpression */
