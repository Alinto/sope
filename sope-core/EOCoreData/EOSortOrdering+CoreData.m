/*
  Copyright (C) 2005 SKYRIX Software AG
  
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

#include "EOSortOrdering+CoreData.h"
#include "common.h"

@implementation EOSortOrdering(CoreData)

- (id)initWithSortDescriptor:(NSSortDescriptor *)_descriptor {
  SEL sel;
  
  if (_descriptor == nil) {
    [self release];
    return nil;
  }
  
  sel = [_descriptor selector];
  if (SEL_EQ(sel, @selector(compare:))) {
    sel = [_descriptor ascending] 
      ? EOCompareAscending
      : EOCompareDescending;
  }
  else if (SEL_EQ(sel, @selector(caseInsensitiveCompare:))) {
    sel = [_descriptor ascending] 
      ? EOCompareCaseInsensitiveAscending
      : EOCompareCaseInsensitiveDescending;
  }
  else {
    if (![_descriptor ascending]) {
      NSLog(@"WARNING(%s): cannot representing descending selector in "
	    @"NSSortDescriptor: %@", __PRETTY_FUNCTION__, _descriptor);
    }
  }
  
  return [self initWithKey:[_descriptor key] selector:sel];
}

- (BOOL)isAscendingEOSortSelector:(SEL)_sel {
  if (SEL_EQ(_sel, EOCompareDescending)) return NO;
  if (SEL_EQ(_sel, EOCompareCaseInsensitiveAscending)) return NO;
  return YES;
}

- (SEL)cdSortSelectorFromEOSortSelector:(SEL)_sel {
  if (SEL_EQ(_sel, EOCompareAscending))  return @selector(compare:);
  if (SEL_EQ(_sel, EOCompareDescending)) return @selector(compare:);
  
  if (SEL_EQ(_sel, EOCompareCaseInsensitiveAscending))
    return @selector(caseInsensitiveCompare:);
  if (SEL_EQ(_sel, EOCompareCaseInsensitiveDescending))
    return @selector(caseInsensitiveCompare:);
  
  return _sel;
}

- (NSSortDescriptor *)asSortDescriptor {
  SEL sel;

  sel = [self selector];
  
  return [[[NSSortDescriptor alloc] 
	    initWithKey:[self key]
	    ascending:[self isAscendingEOSortSelector:sel]
	    selector:[self cdSortSelectorFromEOSortSelector:sel]] autorelease];
}

@end /* EOSortOrdering(CoreData) */


@implementation NSSortDescriptor(EOCoreData)

- (NSSortDescriptor *)asSortDescriptor {
  return self;
}

@end /* NSSortDescriptor(EOCoreData) */
