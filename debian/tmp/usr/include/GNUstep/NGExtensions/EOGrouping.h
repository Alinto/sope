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

#ifndef _EOGrouping_h__
#define _EOGrouping_h__

#import <Foundation/NSObject.h>

@class NSString, NSArray, NSMutableArray;
@class EOQualifier;

@interface EOGrouping : NSObject
{
  NSString *defaultName;
  NSArray  *sortOrderings;
}

- (id)initWithDefaultName:(NSString *)_defaultName;

- (NSString *)defaultName;
- (void)setDefaultName:(NSString *)_defaultName;

- (NSArray *)sortOrderings;
- (void)setSortOrderings:(NSArray *)_sortOrderings;

- (NSString *)groupNameForObject:(id)object;
- (NSArray *)orderedGroupNames;

@end

@interface EOGroupingSet : EOGrouping
{
  NSArray *groupings;
}

- (NSArray *)groupings;
- (void)setGroupings:(NSArray *)_groupings;

@end

@interface EOKeyGrouping : EOGrouping
{
  NSString       *key;
  NSMutableArray *groupNames; /* ??? to be fixed */
}

- (id)initWithKey:(NSString *)_key;

- (NSString *)key;
- (void)setKey:(NSString *)_key;

@end

@interface EOQualifierGrouping : EOGrouping
{
  EOQualifier *qualifier;
  NSString    *name;
}

- (id)initWithQualifier:(EOQualifier *)_qualifier name:(NSString *)_name;

- (void)setName:(NSString *)_name;
- (NSString *)name;

- (void)setQualifier:(EOQualifier *)_qualifier;
- (EOQualifier *)qualifier;

@end

#import <Foundation/NSArray.h>

@class NSDictionary;

@interface NSArray(EOGrouping)
- (NSDictionary *)arrayGroupedBy:(EOGrouping *)_grouping;
@end

#import <EOControl/EOFetchSpecification.h>

extern NSString *EOGroupingHint;

@interface EOFetchSpecification(Groupings)
- (void)setGroupings:(NSArray *)_groupings;
- (NSArray *)groupings;
@end

#endif /* _EOGrouping_h__ */
