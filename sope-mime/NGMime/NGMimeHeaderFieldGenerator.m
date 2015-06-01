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

#include "NGMimeHeaderFieldGenerator.h"
#include "NGMimeHeaderFields.h"
#include "common.h"

@implementation NGMimeHeaderFieldGenerator

+ (id)headerFieldGenerator {
  return [[[self alloc] init] autorelease];
}

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end /* NGMimeHeaderFieldGenerator */

/*
   text       :=  ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "'" /
                  "*" / "+" / "-" / "/" / "^" /  "`" / "{" / "|" /
                  "}" / "~"

  tspecials   :=  "(" / ")" / "<" / ">" / "@" / "," / ";" /
                  ":" / "\" / <"> / "/" / "[" / "]" / "?" /
                  "=" / "_"

  rfc822_text := 1*<any (US-ASCII) CHAR except SPACE, CTLs, or tspecials>
*/
static unsigned char rfc822_text[256] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 0-15 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 16-31 */
    0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, /* 32-47 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, /* 48-63 */
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, /* 64-79 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, /* 80-95 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, /* 96-111 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, /* 112-127 */

    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* >= 128 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

BOOL NGEncodeQuotedPrintableMimeNeeded(const unsigned char *src, unsigned srcLen)
{
  unsigned i = 0;

  for (i = 0; i < srcLen; i++) {
    if (src[i] != ' ' && !rfc822_text[src[i]]) {
      return YES;
    }
  }

  return NO;
}

int NGEncodeQuotedPrintableMime(const unsigned char *src, unsigned srcLen,
                                unsigned char *dest, unsigned destLen)
{
  unsigned cnt = 0;
  unsigned destCnt = 0;
  unsigned char hexT[16] = {'0', '1', '2', '3', '4', '5', '6', '7',
                            '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

  if (srcLen > destLen)
    return -1;

  for (cnt = 0; cnt < srcLen && destCnt < destLen; cnt++) {
    register unsigned char c = src[cnt];

    if (rfc822_text[c] == 1) {
      // no quoting
      dest[destCnt] = c;
      destCnt++;
    } else {
      // need to be quoted
      if (destLen - destCnt <= 2)
        break;

      if (c == ' ') {
        // Special case ' ' => '_' (and '_' will be encoded)
        dest[destCnt] = '_'; destCnt++;
      } else {
        dest[destCnt] = '='; destCnt++;
        dest[destCnt] = hexT[(c >> 4) & 15]; destCnt++;
        dest[destCnt] = hexT[c & 15]; destCnt++;
      }
    }
  }

  if (cnt < srcLen)
    return -1;

  return destCnt;
}
