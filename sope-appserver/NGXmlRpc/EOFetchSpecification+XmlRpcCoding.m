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

#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOSortOrdering.h>
#include "common.h"
#include <XmlRpc/XmlRpcCoder.h>
#import <EOControl/EOQualifier.h>

@implementation EOFetchSpecification(XmlRpcCoding)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  if ((self = [super init])) {
    id q;
    
    [self setUsesDistinct:[_coder decodeBooleanForKey:@"usesDistinct"]];
    [self setLocksObjects:[_coder decodeBooleanForKey:@"locksObjects"]];
    [self setEntityName:  [_coder decodeStringForKey:@"entityName"]];
    [self setFetchLimit:  [_coder decodeIntForKey:@"fetchLimit"]];
    [self setHints:       [_coder decodeStructForKey:@"hints"]];
    
    if ((q = [_coder decodeObjectForKey:@"qualifier"])) {
      if ([q isKindOfClass:[EOQualifier class]])
        /* already a qualifier :-) [ObjC on the other side ..] */
        [q retain];
      else {
        q = [[EOQualifier alloc] initWithPropertyList:q owner:nil];
      }
    }
    
    [self setQualifier:q];
    [self setSortOrderings:[_coder decodeObjectForKey:@"sortOrderings"]];
    
    [q release];
  }
  return self;
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeBoolean:[self usesDistinct] forKey:@"usesDistinct"];
  [_coder encodeBoolean:[self locksObjects] forKey:@"locksObjects"];
  [_coder encodeString:[self entityName]    forKey:@"entityName"];
  [_coder encodeInt:[self fetchLimit]       forKey:@"fetchLimit"];
  [_coder encodeStruct:[self hints]         forKey:@"hints"];
  [_coder encodeObject:[self qualifier]     forKey:@"qualifier"];
  [_coder encodeObject:[self sortOrderings] forKey:@"sortOrderings"];
}

@end /* EOFetchSpecification(XmlRpcCoding) */
