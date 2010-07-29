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
/* Unicode support */

typedef unsigned long	UCS4;
typedef unsigned short	UCS2;
typedef unsigned short	UTF16;
typedef unsigned char	UTF8;
#define unichar UTF16

static const int halfShift             = 10;
static const UCS4 halfBase             = 0x0010000UL;
static const UCS4 halfMask             = 0x3FFUL;
static const UCS4 kSurrogateHighStart  = 0xD800UL;
static const UCS4 kSurrogateLowStart   = 0xDC00UL;

static const UCS4 kReplacementCharacter = 0x0000FFFDUL;
static const UCS4 kMaximumUCS2          = 0x0000FFFFUL;
static const UCS4 kMaximumUTF16         = 0x0010FFFFUL;

static UCS4 offsetsFromUTF8[6] = {
  0x00000000UL, 0x00003080UL, 0x000E2080UL, 
  0x03C82080UL, 0xFA082080UL, 0x82082080UL
};
static char bytesFromUTF8[256] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5
};

static int
_UTF8ToUTF16(unsigned char **sourceStart, unsigned char *sourceEnd, 
             unichar **targetStart, const unichar *targetEnd)
{
  int            result = 0;
  register UTF8  *source = *sourceStart;
  register UTF16 *target = *targetStart;
  
  while (source < sourceEnd) {
    register UCS4 ch = 0;
    register unsigned short extraBytesToWrite = bytesFromUTF8[*source];
    
    if (source + extraBytesToWrite > sourceEnd) {
      result = 1; break;
    };
    switch(extraBytesToWrite) { /* note: code falls through cases! */
      case 5:   ch += *source++; ch <<= 6;
      case 4:   ch += *source++; ch <<= 6;
      case 3:   ch += *source++; ch <<= 6;
      case 2:   ch += *source++; ch <<= 6;
      case 1:   ch += *source++; ch <<= 6;
      case 0:   ch += *source++;
    };
    ch -= offsetsFromUTF8[extraBytesToWrite];

    if (target >= targetEnd) {
      result = 2; break;
    };
    if (ch <= kMaximumUCS2) {
      *target++ = ch;
    } else if (ch > kMaximumUTF16) {
      *target++ = kReplacementCharacter;
    } else {
      if (target + 1 >= targetEnd) {
        result = 2; break;
      };
      ch -= halfBase;
      *target++ = (ch >> halfShift) + kSurrogateHighStart;
      *target++ = (ch & halfMask) + kSurrogateLowStart;
    };
  };
  *sourceStart = source;
  *targetStart = target;
  return result;
}
