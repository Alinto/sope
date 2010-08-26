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

+ (int)version {
  return 2;
}

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

#if 1
int NGEncodeQuotedPrintableMime
(const unsigned char *_src, unsigned _srcLen,
 unsigned char *_dest, unsigned _destLen) 
{
  /* decode also spaces*/
  unsigned cnt      = 0;
  unsigned destCnt  = 0;
  unsigned char
    hexT[16] = {'0','1','2','3','4','5','6','7','8',
                '9','A','B','C','D','E','F'};
  
  if (_srcLen > _destLen)
    return -1;
  
  for (cnt = 0; (cnt < _srcLen) && (destCnt < _destLen); cnt++) {
    register unsigned char c = _src[cnt];

    /* RFC 2045, Sect. 6.7 allows chars 33 through 60 inclusive, and 62 through 126, inclusive
     * RFC 2047, Sect. 4.2 also requires chars 63 and 95 to be encoded
     * Space might be "_", but let's encode it, too... */
    if (((c >= 33) && (c <= 60)) ||
	(c == 62) ||
        ((c >= 64) && (c <= 94)) ||
	((c >= 96) && (c <= 126))) {
      // no quoting
      _dest[destCnt] = c;
      destCnt++;
    }
    else { // need to be quoted
      if (_destLen - destCnt > 2) {
        if (c == ' ') {
          _dest[destCnt] = '_'; destCnt++;
        }
        else {
          _dest[destCnt] = '='; destCnt++;
          _dest[destCnt] = hexT[(c >> 4) & 15]; destCnt++;
          _dest[destCnt] = hexT[c & 15]; destCnt++;
        }
      }
      else 
        break;
    }
  }
  if (cnt < _srcLen)
    return -1;
  return destCnt;
}

#else /* TODO: this one was declared in NGMimeMessageGenerator, any diff? */

static int NGEncodeQuotedPrintableMime(const char *_src, unsigned _srcLen,
                                       char *_dest, unsigned _destLen) {
  /* decode also spaces*/
  unsigned cnt      = 0;
  unsigned destCnt  = 0;
  char     hexT[16] = {'0','1','2','3','4','5','6','7','8',
                       '9','A','B','C','D','E','F'};
  
  if (_srcLen > _destLen)
    return -1;
  
  for (cnt = 0; (cnt < _srcLen) && (destCnt < _destLen); cnt++) {
    char c = _src[cnt];

    if (((c > 47) && (c < 58)) ||
        ((c > 64) && (c < 91)) ||
        ((c > 96) && (c < 123))) { // no quoting
      _dest[destCnt++] = c;
    }
    else { // need to be quoted
      if (_destLen - destCnt > 2) {
        _dest[destCnt++] = '=';
        _dest[destCnt++] = hexT[(c >> 4) & 15];
        _dest[destCnt++] = hexT[c & 15];
      }
      else 
        break;
    }
  }
  if (cnt < _srcLen)
    return -1;
  return destCnt;
}

#endif
