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
#import "NSData+misc.h"

@implementation NSData(misc)

- (BOOL)hasPrefix:(NSData *)_data {
  return [self hasPrefixBytes:[_data bytes] length:[_data length]];
}

- (BOOL)hasPrefixBytes:(const void *)_bytes length:(unsigned)_len {
  if (_len > [self length])
    return NO;
  else {
    const unsigned char *ownBytes = [self bytes];
    register unsigned i;

    for (i = 0; i < _len; i++) {
      if (((unsigned char *)_bytes)[i] != ownBytes[i])
        return NO;
    }
    return YES;
  }
}

@end /* NSData(misc) */

void __link_NSData_misc() {
  __link_NSData_misc();
}
