/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#import <Foundation/NSData.h>

#include <NGImap4/NSString+Imap4.h>
#include "imCommon.h"

@implementation NSString(Imap4)

static unsigned int _encodeToModifiedUTF7(unichar *_char, unsigned char *result_,
                                          unsigned int *cntRes_);
static unsigned int _decodeOfModifiedUTF7(unsigned char *_source, unichar *result_,
                                          unsigned int *cntRes_ );

- (NSString *)stringByEncodingImap4FolderName {
  unichar       *buf    = NULL;
  unsigned char *res    = NULL;
  unsigned int  len     = 0;
  unsigned int  cnt     = 0;
  unsigned int  cntRes  = 0;
  NSString      *result = nil;

  len = [self length];
  buf = NSZoneMalloc(NULL, (len + 1) * sizeof(unichar));
  [self getCharacters: buf];
  buf[len] = 0;

  /* 1 * '&', 3 for the max bytes / char, 1 * '-' */
  res = NSZoneMalloc(NULL, ((len * 5) + 1) * sizeof(char));

  while (cnt < len) {
    unichar c = buf[cnt];
    if (((c > 31) && (c < 38)) ||
        ((c > 38) && (c < 127))) {
      res[cntRes++] = c;
    }
    else {
      if (c == '&') {
        res[cntRes++]  = '&';
        res[cntRes++]  = '-';
      }
      else {
        res[cntRes++] = '&';
        cnt += _encodeToModifiedUTF7(buf + cnt, res + cntRes, &cntRes);
        res[cntRes++] = '-';
      }
    }
    cnt++;
  }
  if (buf != NULL) NSZoneFree(NULL, buf);

  res[cntRes] = 0;
  result = [NSString stringWithCString: (char *) res
                              encoding: NSISOLatin1StringEncoding];

  return result;
}

- (NSString *)stringByDecodingImap4FolderName {
  unsigned char *buf;
  unichar *res;
  unsigned int  len;
  unsigned int  cnt     = 0;
  unsigned int  cntRes  = 0;
  NSString      *result = nil;
//   NSData        *data;
  
  if ((len = [self lengthOfBytesUsingEncoding: NSISOLatin1StringEncoding]) == 0)
    return @"";

  buf = NSZoneMalloc(NULL, (len + 1) * sizeof(unsigned char));

  if ([self getCString:(char *)buf maxLength: len + 1
              encoding: NSISOLatin1StringEncoding] == NO) {
    NSZoneFree(NULL, buf);
    return @"";
  }
  buf[len] = '\0';

  res = NSZoneMalloc(NULL, (len + 1) * sizeof(unichar));

  while (cnt < len) { /* &- */
    unsigned char c;

    c = buf[cnt];

    if (c == '&') {
      if (buf[cnt + 1] == '-') {
        res[cntRes++] = '&';
        cnt += 2;
      }
      else {
        cnt += _decodeOfModifiedUTF7(buf + cnt + 1, res + cntRes, &cntRes) + 1;
      }
    }
    else {
      res[cntRes++] = c;
      cnt++;
    }
  }

  if (buf != NULL) NSZoneFree(NULL, buf);

  res[cntRes] = 0;
  result = [NSString stringWithCharacters: res length: cntRes];

  return result;
}

/* check metamail output for correctness */

static unsigned char basis_64[] =
   "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char index_64[128] = {
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,62, -1,-1,-1,63,
    52,53,54,55, 56,57,58,59, 60,61,-1,-1, -1,-1,-1,-1,
    -1, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
    15,16,17,18, 19,20,21,22, 23,24,25,-1, -1,-1,-1,-1,
    -1,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
    41,42,43,44, 45,46,47,48, 49,50,51,-1, -1,-1,-1,-1
};

#define char64(c)  (((c) < 0 || (c) > 127) ? -1 : index_64[(c)])

static unsigned int _encodeToModifiedUTF7(unichar *_char, unsigned char *result_,
                                          unsigned int *cntRes_)
{
  unsigned int processedSrc, processedDest, cycle;
  unichar c;
  char leftover;
  BOOL hasLeftOver;

  processedSrc = 0;
  processedDest = 0;
  cycle = 0;
  leftover = 0;

  c = *_char;
  while (c > 126 || (c > 0 && c < 32)) {
    if (cycle == 0) {
      *(result_ + processedDest) = basis_64[(c >> 10) & 0x3f];
      *(result_ + processedDest + 1) = basis_64[(c >> 4) & 0x3f];
      leftover = (c << 2);
      hasLeftOver = YES;
      processedDest += 2;
      cycle = 1;
    }
    else if (cycle == 1) {
      *(result_ + processedDest) = basis_64[(leftover | (c >> 14)) & 0x3f];
      *(result_ + processedDest + 1) = basis_64[(c >> 8) & 0x3f];
      *(result_ + processedDest + 2) = basis_64[(c >> 2) & 0x3f];
      leftover = (c << 4);
      hasLeftOver = YES;
      processedDest += 3;
      cycle = 2;
    }
    else if (cycle == 2) {
      *(result_ + processedDest) = basis_64[(leftover | (c >> 12)) & 0x3f];
      *(result_ + processedDest + 1) = basis_64[(c >> 6) & 0x3f];
      *(result_ + processedDest + 2) = basis_64[c & 0x3f];
      leftover = 0;
      hasLeftOver = NO;
      processedDest += 3;
      cycle = 0;
    }
    processedSrc++;
    c = *(_char + processedSrc);
  }
  if (hasLeftOver) {
    *(result_ + processedDest) = basis_64[leftover & 0x3f];
    processedDest++;
  }
  processedSrc--;
  *cntRes_ += processedDest;

  return processedSrc;
}

static unsigned int _decodeOfModifiedUTF7(unsigned char *_source, unichar *result_,
                                          unsigned int *cntRes_)
{
  unsigned int processedSrc, processedDest;
  unsigned char c, decoded;
  unichar currentRes;
  int shift;

  processedSrc = 0;
  processedDest = 0;
  shift = 10;
  currentRes = 0;

  c = *_source;
  while (c != 0 && c != '-') {
    decoded = index_64[c];
    if (shift < 0) {
      currentRes |= (decoded >> (shift * -1));
      *(result_ + processedDest) = currentRes;
      processedDest++;
      shift += 16;
      currentRes = (decoded << shift);
    } else {
      currentRes |= (decoded << shift);
      if (shift == 0) {
        *(result_ + processedDest) = currentRes;
        processedDest++;
        currentRes = 0;
        shift = 16;
      }
    }
    shift -= 6;
    processedSrc++;
    c = *(_source + processedSrc);
  }
  if (shift != 10) {
    *(result_ + processedDest) = currentRes;
  }
  if (c == '-')
    processedSrc++;

  *cntRes_ += processedDest;

  return processedSrc;
}

@end /* NSString(Imap4) */
