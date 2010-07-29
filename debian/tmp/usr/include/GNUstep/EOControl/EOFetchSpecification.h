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

#ifndef __EOFetchSpecification_h__
#define __EOFetchSpecification_h__

#import <Foundation/NSObject.h>

@class NSArray, NSString, NSDictionary;
@class EOQualifier;

@interface EOFetchSpecification : NSObject < NSCopying >
{
  NSString     *entityName;
  EOQualifier  *qualifier;
  NSArray      *sortOrderings;
  unsigned     fetchLimit;
  NSDictionary *hints;
  struct {
    int usesDistinct:1;
    int locksObjects:1;
    int deep:1;
    int reserved:29;
  } fsFlags;
}

+ (EOFetchSpecification *)fetchSpecificationWithEntityName:(NSString *)_ename
  qualifier:(EOQualifier *)_qualifier
  sortOrderings:(NSArray *)sortOrderings;

- (id)initWithEntityName:(NSString *)_name
  qualifier:(EOQualifier *)_qualifier
  sortOrderings:(NSArray *)_sortOrderings
  usesDistinct:(BOOL)_dflag isDeep:(BOOL)_isDeep
  hints:(NSDictionary *)_hints;

/* accessors */

- (void)setEntityName:(NSString *)_name;
- (NSString *)entityName;

- (void)setQualifier:(EOQualifier *)_qualifier;
- (EOQualifier *)qualifier;

- (void)setSortOrderings:(NSArray *)_orderings;
- (NSArray *)sortOrderings;

- (void)setUsesDistinct:(BOOL)_flag;
- (BOOL)usesDistinct;

- (void)setIsDeep:(BOOL)_flag;
- (BOOL)isDeep;

- (void)setLocksObjects:(BOOL)_flag;
- (BOOL)locksObjects;

- (void)setFetchLimit:(unsigned)_limit;
- (unsigned)fetchLimit;

- (void)setHints:(NSDictionary *)_hints;
- (NSDictionary *)hints;

/* bindings */

- (EOFetchSpecification *)fetchSpecificationWithQualifierBindings:(NSDictionary *)_bindings;

/* remapping keys */

- (EOFetchSpecification *)fetchSpecificationByApplyingKeyMap:(NSDictionary *)_m;

@end

#endif /* __EOFetchSpecification_h__ */
