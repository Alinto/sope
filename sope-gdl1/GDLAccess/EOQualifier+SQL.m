/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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
// $Id: EOQualifier+SQL.m 1 2004-08-20 10:38:46Z znek $

#include "EOSQLExpression.h"
#include "EOSQLQualifier.h"
#include <EOControl/EOQualifier.h>
#include "common.h"

@implementation EOAndQualifier(SQLGeneration)

- (NSString *)sqlStringForSQLExpression:(EOSQLExpression *)_sqlExpr {
  return [_sqlExpr sqlStringForConjoinedQualifiers:[self qualifiers]];
}

- (EOQualifier *)schemaBasedQualifierWithRootEntity:(EOEntity *)_entity {
  NSArray  *array;
  id       objects[self->count + 1];
  unsigned i;

  IMP objAtIdx;

  objAtIdx = [self->qualifiers methodForSelector:@selector(objectAtIndex:)];
  
  for (i = 0; i < self->count; i++) {
    id q, newq;

    q = objAtIdx(self->qualifiers, @selector(objectAtIndex:), i);
    newq = [q schemaBasedQualifierWithRootEntity:_entity];
    if (newq == nil) newq = q;
    
    objects[i] = newq;
  }

  array = [NSArray arrayWithObjects:objects count:self->count];
  return [[[[self class] alloc] initWithQualifierArray:array] autorelease];
}

@end /* EOAndQualifier(SQLGeneration) */

@implementation EOOrQualifier(SQLGeneration)

- (NSString *)sqlStringForSQLExpression:(EOSQLExpression *)_sqlExpr {
  return [_sqlExpr sqlStringForDisjoinedQualifiers:[self qualifiers]];
}

- (EOQualifier *)schemaBasedQualifierWithRootEntity:(EOEntity *)_entity {
  NSArray  *array;
  id       objects[self->count + 1];
  unsigned i;

  IMP objAtIdx;

  objAtIdx = [self->qualifiers methodForSelector:@selector(objectAtIndex:)];
  
  for (i = 0; i < self->count; i++) {
    id q, newq;

    q = objAtIdx(self->qualifiers, @selector(objectAtIndex:), i);
    newq = [q schemaBasedQualifierWithRootEntity:_entity];
    if (newq == nil) newq = q;
    
    objects[i] = newq;
  }

  array = [NSArray arrayWithObjects:objects count:self->count];
  return [[[[self class] alloc] initWithQualifierArray:array] autorelease];
}

@end /* EOOrQualifier(SQLGeneration) */

@implementation EONotQualifier(SQLGeneration)

- (NSString *)sqlStringForSQLExpression:(EOSQLExpression *)_sqlExpr {
  return [_sqlExpr sqlStringForNegatedQualifier:[self qualifier]];
}

- (EOQualifier *)schemaBasedQualifierWithRootEntity:(EOEntity *)_entity {
  EOQualifier *sq;

  sq = [(id<EOQualifierSQLGeneration>)self->qualifier
           schemaBasedQualifierWithRootEntity:_entity];
  if (sq == self->qualifier)
    return self;

  sq = [[EONotQualifier alloc] initWithQualifier:sq];
  return [sq autorelease];
}

@end /* EONotQualifier(SQLGeneration) */

@implementation EOKeyValueQualifier(SQLGeneration)

- (NSString *)sqlStringForSQLExpression:(EOSQLExpression *)_sqlExpr {
  return [_sqlExpr sqlStringForKeyValueQualifier:self];
}

- (EOQualifier *)schemaBasedQualifierWithRootEntity:(EOEntity *)_entity {
  NSLog(@"ERROR(%s): subclasses need to override this method!",
	__PRETTY_FUNCTION__);
  return nil;
}

@end /* EOKeyValueQualifier(SQLGeneration) */

@implementation EOKeyComparisonQualifier(SQLGeneration)

- (NSString *)sqlStringForSQLExpression:(EOSQLExpression *)_sqlExpr {
  return [_sqlExpr sqlStringForKeyComparisonQualifier:self];
}

- (EOQualifier *)schemaBasedQualifierWithRootEntity:(EOEntity *)_entity {
  NSLog(@"ERROR(%s): subclasses need to override this method!",
	__PRETTY_FUNCTION__);
  return nil;
}

@end /* EOKeyComparisonQualifier(SQLGeneration) */
