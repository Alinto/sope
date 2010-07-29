/*
  Copyright (C) 2004 eXtrapola Srl

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

#include "NSString+STX.h"
#include "common.h"

@implementation NSString(STX)

- (StructuredText *)structuredText {
  return [[[StructuredText alloc] initWithString:self] autorelease];
}

- (NSString *)unescapedString {
  NSMutableString *result;
  NSString        *text;
  int             i, start, length;
  NSRange         range;
  
  result = [NSMutableString stringWithCapacity:[self length]];

  text = self;
  length = [text length];

  for (i = start = 0; i < length; i++) {
    unichar c;

    c = [text characterAtIndex:i];

    if (c == '\\') {
      if (i - start > 0) {
	range.location = start;
	range.length = i - start;

	[result appendString:[text substringWithRange:range]];
      }

      if (i + 1 < length) {
	c = [text characterAtIndex:i + 1];

	if (c == '\\') {
	  start = ++i;
	}
      }
    }
  }

  if (i - start > 0) {
    range.location = start;
    range.length = i - start;

    [result appendString:[text substringWithRange:range]];
  }

  return result;
}

@end /* NSString(STX) */
