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

#include "imCommon.h"

@interface NSObject(IMAPAdditions)
- (NSString *)imap4SortString;
@end

@implementation NSString(IMAPAdditions)

- (NSString *)imap4SortString {
  /* support preformatted sort strings */
  return self;
}

@end /* NSString(IMAPAdditions) */

@implementation EOSortOrdering(IMAPAdditions)

static NSArray *AllowedSortKeys = nil;

- (void)_setupAllowedIMAP4SortKeys {
  if (AllowedSortKeys != nil)
    return;
  
  AllowedSortKeys = [[NSArray alloc] initWithObjects:
                                         @"ARRIVAL", @"CC", @"DATE", @"FROM",
                                     @"SIZE", @"SUBJECT", @"TO", @"MODSEQ",
                                     nil];
}

- (NSString *)imap4SortString {
  SEL      sel;
  NSString *lkey;
    
  lkey = [self key];
  if (![lkey isNotEmpty])
    return nil;

  /* check whether key is a valid sort string */
  
  if (AllowedSortKeys == nil) [self _setupAllowedIMAP4SortKeys];
  if (![AllowedSortKeys containsObject:[lkey uppercaseString]]) {
    NSLog(@"ERROR[%s] key %@ is not allowed here!",
	  __PRETTY_FUNCTION__, lkey);
    return nil;
  }
  
  /* check selector */
  
  sel = [self selector];
  if (sel_eq(sel, EOCompareDescending) ||
      sel_eq(sel, EOCompareCaseInsensitiveDescending)) {
    return [@"REVERSE " stringByAppendingString:lkey];
  }
  // TODO: check other selectors whether they make sense instead of silent acc.
  
  return lkey;
}

@end /* EOSortOrdering(IMAPAdditions) */

@implementation NSArray(IMAPAdditions)

- (NSString *)imap4SortStringForSortOrderings {
  /*
    turn EOSortOrdering into an IMAP4 value for "SORT()"
    
    eg: "DATE REVERSE SUBJECT"
    
    It also checks a set of allowed sort-keys (don't know why)
  */
  NSMutableString *sortStr;
  unsigned i, count;
  
  if ((count = [self count]) == 0)
    return nil;
  
  sortStr = [NSMutableString stringWithCapacity:(count * 24)];
  
  for (i = 0; i < count; i++) {
    EOSortOrdering *so;
    NSString *s;

    so = [self objectAtIndex:i];
    if (![so isNotNull])
      continue;
    if ((s = [so imap4SortString]) == nil)
      continue;
    
    if (i > 0) [sortStr appendString:@" "];
    [sortStr appendString:s];
  }
  return [sortStr isNotEmpty] ? sortStr : (NSMutableString *)nil;
}

@end /* NSArray(IMAPAdditions) */
