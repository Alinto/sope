/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

@implementation NGMimeStringHeaderFieldParser

static BOOL StripLeadingSpaces = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  StripLeadingSpaces = [self doesStripLeadingSpaces];
}

- (id)initWithRemoveComments:(BOOL)_flag {
  if ((self = [super init])) {
    self->removeComments = _flag;
  }
  return self;
}
- (id)init {
  return [self initWithRemoveComments:YES];
}

/* operation */

- (id)parseValue:(id)_value ofHeaderField:(NSString *)_field {
  // TODO: fixup
  unsigned len = [_value length];
  unsigned cnt;
  unichar  src[len + 1];
  NSString *res;
  
  if (_value == nil)
    return nil;
  
  if (len == 0)
    return @"";

  res = self->removeComments
    ? [self removeCommentsFromValue:_value] : (NSString *)_value;

  if (StripLeadingSpaces) { /* currently be done during header field parsing */
    [res getCharacters:src];
    // strip leading spaces
    cnt     = 0;
  
    while (isRfc822_LWSP(src[cnt]) && (len > 0)) {
      cnt++;
      len--;
    }
    if (cnt > 0)
      res = [[[NSString alloc] initWithCharacters:src+cnt length:len]
                        autorelease];
  }
  return res;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<MimeStringHeaderFieldParser: id=0x%p"
                     @" removesComments=%s>",
                     self, self->removeComments ? "YES" : "NO"];
}

@end /* NGMimeStringHeaderFieldParser */
