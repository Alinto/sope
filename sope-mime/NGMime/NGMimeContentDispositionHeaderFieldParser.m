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

@implementation NGMimeContentDispositionHeaderFieldParser

static BOOL StripLeadingSpaces = NO;
static BOOL MimeLogEnabled     = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  StripLeadingSpaces = [self doesStripLeadingSpaces];
  MimeLogEnabled     = [self isMIMELogEnabled];
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  unsigned   len = [_data length];
  unichar    src[len + 1];
  unsigned   cnt;
  BOOL       didModify;
  NSString   *str;
  
  didModify = NO;
  cnt       = 0;

  [_data getCharacters:src];
  
  /* strip leading spaces */
  if (StripLeadingSpaces) {
    while (isRfc822_LWSP(src[cnt]) && (len > 0)) {
      cnt++;
      len--;
      didModify = YES;
    }
  }
  /* strip trailing spaces */
  while (len > 0) {
    if (isRfc822_LWSP(src[len - 1])) {
      len--;
      didModify = YES;
    }
    else
      break;
  }
  if (len == 0) {
    if (MimeLogEnabled) 
      [self logWithFormat:@"WARNING(%s): empty value for header field %@ ..",
            __PRETTY_FUNCTION__, _field];
    return nil;
  }
  str = nil;
  
  str = (didModify)
    ? [NSString stringWithCharacters:(src + cnt) length:len]
    : _data;
  
  return [[[NGMimeContentDispositionHeaderField alloc] initWithString:str]
                                                autorelease];
}

@end /* NGMimeContentDispositionHeaderFieldParser */
