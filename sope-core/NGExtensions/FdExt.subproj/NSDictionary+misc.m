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

#import "common.h"
#import "NSDictionary+misc.h"

@implementation NSDictionary(misc)

- (NSDictionary *)dictionaryByExchangingKeysAndValues {
  NSDictionary *reverse;
  NSArray  *oKeys;
  unsigned i, len;
  id *keys, *values;
  
  oKeys = [self allKeys];
  if ((len = [oKeys count]) == 0)
    return [[self copy] autorelease];
  
  keys   = calloc(len + 10, sizeof(id));
  values = calloc(len + 10, sizeof(id));
  for (i = 0; i < len; i++) {
    values[i] = [oKeys objectAtIndex:i];
    keys[i]   = [self objectForKey:values[i]];
  }
  
  reverse =
    [[NSDictionary alloc] initWithObjects:values forKeys:keys count:len];
  free(keys);
  free(values);
  return [reverse autorelease];
}

@end /* NSDictionary(misc) */

@implementation NSMutableDictionary(misc)

- (void)removeObjectsForKeysV:(id)_firstKey, ... {
  va_list ap;

  va_start(ap, _firstKey);
  while (_firstKey) {
    [self removeObjectForKey:_firstKey];
    _firstKey = va_arg(ap, id);
  }
  va_end(ap);
}

@end /* NSMutableDictionary(misc) */

void __link_NSDictionary_misc() {
  __link_NSDictionary_misc();
}
