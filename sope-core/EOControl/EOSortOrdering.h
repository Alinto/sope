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

#ifndef __EOControl_EOSortOrdering_H__
#define __EOControl_EOSortOrdering_H__

#import <Foundation/NSObject.h>
#include <EOControl/EOControlDecls.h>
#include <EOControl/EOKeyValueArchiver.h>

@class NSDictionary, NSString;

#define EOCompareAscending  @selector(compareAscending:)
#define EOCompareDescending @selector(compareDescending:)
#define EOCompareCaseInsensitiveAscending  @selector(compareCaseInsensitiveAscending:)
#define EOCompareCaseInsensitiveDescending @selector(compareCaseInsensitiveDescending:)

@interface EOSortOrdering : NSObject < EOKeyValueArchiving >
{
  NSString *key;
  SEL      selector;
}

+ (EOSortOrdering *)sortOrderingWithKey:(NSString *)_key 
  selector:(SEL)_selector;
- (id)initWithKey:(NSString *)_key selector:(SEL)_selector;

/* accessors */

- (NSString *)key;
- (SEL)selector;

/* remapping keys */

- (EOSortOrdering *)sortOrderingByApplyingKeyMap:(NSDictionary *)_map;

@end

#import <Foundation/NSArray.h>

@interface NSArray(EOSortOrdering)

- (NSArray *)sortedArrayUsingKeyOrderArray:(NSArray *)_orderings;

@end

@interface NSMutableArray(EOSortOrdering)

- (void)sortUsingKeyOrderArray:(NSArray *)_orderings;

@end

#import <Foundation/NSString.h>

@interface NSString(EOSortOrdering)
- (int)compareAscending:(id)_object;
- (int)compareDescending:(id)_object;
- (int)compareCaseInsensitiveAscending:(id)_object;
- (int)compareCaseInsensitiveDescending:(id)_object;
@end

#endif /* __EOControl_EOSortOrdering_H__ */
