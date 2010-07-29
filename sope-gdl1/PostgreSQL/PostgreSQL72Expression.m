/* 
   PostgreSQL72Expression.m

   Copyright (C) 1999      MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2006 SKYRIX Software AG and Helge Hess
   
   Author: Helge Hess (helge@opengroupware.org)

   This file is part of the PostgreSQL Adaptor Library

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

#include "PostgreSQL72Expression.h"
#include "common.h"

@implementation PostgreSQL72Expression

+ (Class)selectExpressionClass	{
  return [PostgreSQL72SelectSQLExpression class];
}

@end /* PostgreSQL72Expression */

@implementation PostgreSQL72SelectSQLExpression

- (id)selectExpressionForAttributes:(NSArray *)attributes
  lock:(BOOL)flag
  qualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  channel:(EOAdaptorChannel *)channel {

  lock = flag;
  [super selectExpressionForAttributes:attributes
         lock:flag
         qualifier:qualifier
         fetchOrder:fetchOrder
         channel:channel];
  return self;
}

- (NSString *)fromClause {
  NSMutableString *fromClause;
  NSEnumerator    *enumerator;
  BOOL            first       = YES;
  id              key;
  
  fromClause = [NSMutableString stringWithCapacity:64];
  enumerator = [fromListEntities objectEnumerator];

  [fromClause appendString:@" "];
  
  // Compute the FROM list from all the aliases found in
  // entitiesAndPropertiesAliases dictionary. Note that this dictionary
  // contains entities and relationships. The last ones are there for
  // flattened attributes over reflexive relationships.
  
  while ((key = [enumerator nextObject]) != nil) {
    if(first) first = NO;
    else      [fromClause appendString:@", "];
    
    [fromClause appendString:
                  [key isKindOfClass:[EORelationship class]]
                  ? [[key destinationEntity] externalName]
		    // flattened attribute
  		  : [key externalName]];
                    // EOEntity
    
    [fromClause appendString:@" "];
    [fromClause appendString:
		[[entitiesAndPropertiesAliases objectForKey:key] stringValue]];

#if 0    
    if (lock) [fromClause appendString:@" HOLDLOCK"];
#endif    
  }

  return fromClause;
}

@end

void __link_PostgreSQL72Expression() {
  // used to force linking of object file
  __link_PostgreSQL72Expression();
}
