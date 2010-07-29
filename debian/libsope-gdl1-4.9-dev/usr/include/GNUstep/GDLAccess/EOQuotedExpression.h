/* 
   EOQuotedExpression.h

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

#ifndef __EOQuotedExpression_h__
#define __EOQuotedExpression_h__

#import <GDLAccess/EOExpressionArray.h>

@class NSString;

@interface EOQuotedExpression : NSObject <NSCopying>
{
    id       expression;
    NSString *quote;
    NSString *escape;
}

- (id)expressionValueForContext:(id<EOExpressionContext>)context;

- (id)initWithExpression:(id)expression
  quote:(NSString *)quote
  escape:(NSString *)escape;

@end

#endif /* __EOQuotedExpression_h__ */
