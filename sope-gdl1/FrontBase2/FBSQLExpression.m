/* 
   FBSQLExpression.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBSQLExpression.m 1 2004-08-20 10:38:46Z znek $

#include <Foundation/Foundation.h>
#include <GDLAccess/EOAccess.h>
#include "FBSQLExpression.h"

@implementation FBSQLExpression

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  NSAssert([super version] == 1, @"invalid superclass version !");
}

+ (Class)selectExpressionClass	{
  return [FBSelectSQLExpression class];
}

@end

@implementation FBSelectSQLExpression

- (id)selectExpressionForAttributes:(NSArray *)attributes
  lock:(BOOL)flag
  qualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  channel:(EOAdaptorChannel *)channel
{
  self->lock = flag;
  
  return [super selectExpressionForAttributes:attributes
                lock:flag
                qualifier:qualifier
                fetchOrder:fetchOrder
                channel:channel];
}

- (NSString *)lockClause {
#warning no holdlock !!!
  return @"";
#if 0
  return (self->lock)
    ? @" HOLDLOCK"
    : @"";
#endif
}

@end

void __link_FBSQLExpression() {
  // used to force linking of object file
  __link_FBSQLExpression();
}
