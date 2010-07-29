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

#include "NGMimeHeaderFieldParser.h"
#include "NGMimeHeaderFields.h"
#include "NGMimeUtilities.h"
#include "common.h"

@implementation NGMimeContentLengthHeaderFieldParser

+ (int)version {
  return 2;
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  const char *buf, *ptr;
    
  _data = [self removeCommentsFromValue:_data];
  buf   = [_data cString];
  ptr = buf;
  while (!isRfc822_DIGIT(*ptr) && (*ptr != '\0'))
    ptr++;

  if (isRfc822_DIGIT(*ptr))
    return [NSNumber numberWithUnsignedInt:atol(ptr)];
  else {
    NSLog(@"WARNING(%s): invalid content-length field value (value='%s')",
          __PRETTY_FUNCTION__, buf);
    return nil;
  }
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<MimeContentLengthHeaderFieldParser: object=0x%p>",
                     self];
}

@end /* NGMimeContentLengthHeaderFieldParser */
