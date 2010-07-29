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

#include <NGExtensions/EOSortOrdering+plist.h>
#include "common.h"

@implementation EOSortOrdering(plist)

/*"
  Initialize a sort-ordering with information contained in the dictionary.
  The following keys are recognized: "key" is required and specifies the
  key to be sorted on, "selector" is optional and specifies the sort
  selector as a string. The default for "selector" is EOCompareAscending
  and the following "special" values are recognized: "compareAscending",
  "compareDescending", "compareCaseInsensitiveAscending", 
  "compareCaseInsensitiveDescending".
"*/
- (id)initWithDictionary:(NSDictionary *)_dict {
  NSString *k  = nil;
  SEL      sel = EOCompareAscending;
  NSString *tmp;

  if (_dict == nil) {
    [self release];
    return nil;
  }
  
  k = [_dict objectForKey:@"key"];
  if ([k length] == 0) {
    NSLog(@"%s: invalid key %@ (dict=%@)", __PRETTY_FUNCTION__, k, _dict);
    [self release];
    return nil;
  }
  
  if ((tmp = [[_dict objectForKey:@"selector"] stringValue])) {
    if ([tmp isEqualToString:@"compareAscending"])
      sel = EOCompareAscending;
    else if ([tmp isEqualToString:@"compareDescending"])
      sel = EOCompareDescending;
    else if ([tmp isEqualToString:@"compareCaseInsensitiveAscending"])
      sel = EOCompareCaseInsensitiveAscending;
    else if ([tmp isEqualToString:@"compareCaseInsensitiveDescending"])
      sel = EOCompareCaseInsensitiveDescending;
    else
      sel = NSSelectorFromString(tmp);
  }
  return [self initWithKey:k selector:sel];
}

/*"
  Initialize/parse a sort-ordering from a string. Usually the string is
  taken as the key of the ordering and the sorting EOCompareAscending. This
  can be modified by adding ".reverse" to the key, eg "name.reverse" sorts
  on the "name" key using EOCompareDescending.
"*/
- (id)initWithString:(NSString *)_string {
  SEL      sel;
  NSString *k;
  NSRange  r;
  
  if ([_string length] == 0) {
    [self release];
    return nil;
  }
  
  r = [_string rangeOfString:@".reverse"];
  if (r.length == 0) {
    k    = _string;
    sel = EOCompareAscending;
  }
  else {
    k   = [_string substringToIndex:r.location];
    sel = EOCompareDescending;
  }
  
  return [self initWithKey:k selector:sel];
}

- (id)initWithPropertyList:(id)_plist owner:(id)_owner {
  if (_plist == nil) {
    [self release];
    return nil;
  }
  
  if ([_plist isKindOfClass:[NSDictionary class]])
    return [self initWithDictionary:_plist];
  if ([_plist isKindOfClass:[NSString class]])
    return [self initWithString:_plist];
  
  if ([_plist isKindOfClass:[self class]]) {
    [self release];
    return [_plist copy];
  }
  
  [self release];
  return nil;
}
- (id)initWithPropertyList:(id)_plist {
  return [self initWithPropertyList:_plist owner:nil];
}

@end /* EOSortOrdering(plist) */
