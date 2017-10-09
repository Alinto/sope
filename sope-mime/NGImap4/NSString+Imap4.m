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

#include <NGImap4/NSString+Imap4.h>
#include "imCommon.h"

/* TODO: NOT UNICODE SAFE (uses cString) */

static void _encodeToModifiedUTF7(unsigned char *_buf, int encLen,
                                  unsigned char **result_,
                                  unsigned int *cntRes_);
static int _decodeOfModifiedUTF7(unsigned char *_target, unsigned _targetLen,
                                 unsigned *usedBytes_ ,
                                 unsigned char **buffer_,
                                 int *bufLen_, int maxBuf);

@implementation NSString(Imap4)

- (NSString *)stringByEncodingImap4FolderName {
  // TBD: this is restricted to Latin1, should be fixed to UTF-8
  /* dude.d& --> dude.d&- */
  unsigned char *buf    = NULL;
  unsigned char *res    = NULL;
  unsigned int  len     = 0;
  unsigned int  cnt     = 0;
  unsigned int  cntRes  = 0;
  NSString      *result = nil;
  NSData        *data;

  len = [self cStringLength];
  buf = calloc(len + 3, sizeof(char));  
  res = calloc((len * 6) + 3, sizeof(char));  
  buf[len] = '\0';
  res[len * 6] = '\0';  
  [self getCString:(char *)buf];

  while (cnt < len) {
    int c = buf[cnt];
    if (((c > 31) && (c < 38)) ||
        ((c > 38) && (c < 127))) {
      res[cntRes++] = c;
      cnt++;
    }
    else {
      if (c == '&') {
        res[cntRes++]  = '&';
        res[cntRes++]  = '-';
        cnt++;
      }
      else {
        int start;

        start = cnt;

        while (cnt < (len - 1)) {
          int c = buf[cnt + 1];
          if (((c > 31) && (c < 38)) ||
              ((c > 38) && (c < 127)) ||
              (c == '&')) {
            break;
          }
          else {
            cnt++;
          }
        }
        {
          unsigned length;
          
          res[cntRes++] = '&';

          length = cnt - start + 1;
          
          _encodeToModifiedUTF7(buf + start, length, &res, &cntRes);
          
          res[cntRes] = '-';
	  cntRes++;
          cnt++;
        }
      }
    }
  }
  if (buf != NULL) free(buf); buf = NULL;

  data = [[NSData alloc] initWithBytesNoCopy:res length:cntRes 
			 freeWhenDone:YES];
  result = [[NSString alloc] initWithData:data
			     encoding:NSISOLatin1StringEncoding];
  [data release]; data = nil;
  
  return [result autorelease];
}

- (NSString *)stringByDecodingImap4FolderName {
  // TBD: this is restricted to Latin1, should be fixed to UTF-8
  /* dude/d&- --> dude/d& */
  unsigned char *buf;
  unsigned char *res;
  unsigned int  len;
  unsigned int  cnt     = 0;
  unsigned int  cntRes  = 0;
  NSString      *result = nil;
  NSData        *data;
  
  if ((len = [self cStringLength]) == 0)
    return @"";
  
  buf = calloc(len + 3, sizeof(unsigned char));
  res = calloc(len + 3, sizeof(unsigned char));  
  buf[len] = '\0';
  res[len] = '\0';
  
  [self getCString:(char *)buf];
  
  while (cnt < (len - 1)) { /* &- */
    unsigned char c;

    c = buf[cnt];

    if (c == '&') {
      if (buf[cnt + 1] == '-') {
        res[cntRes++] = '&';
        cnt += 2;
      }
      else {
        unsigned      usedBytes = 0;
        unsigned char *buffer;
        int           maxBuf, bufLen;

        cnt++;
        maxBuf = 511;
        bufLen = 0;
        buffer = calloc(maxBuf + 3, sizeof(char));
        
        if (_decodeOfModifiedUTF7(buf + cnt, len - cnt, &usedBytes , &buffer,
                                  &bufLen, maxBuf) == 0) {
          int  cnt1;
          
          cnt1 = 0;
          while (cnt1 < bufLen) {
            res[cntRes++] = buffer[cnt1++];
          }
          cnt += usedBytes;
        }
        else {
          NSCAssert(NO, @"couldn't decode UTF-7 ..");
        }
        free(buffer); buffer = NULL;
      }
    }
    else {
      res[cntRes++] = c;
      cnt++;
    }
  }
  if (cnt < len)
    res[cntRes++] = buf[cnt++];
  
  if (buf != NULL) free(buf); buf = NULL;

  data = [[NSData alloc] initWithBytesNoCopy:res length:cntRes 
			 freeWhenDone:YES];
  result = [[NSString alloc] initWithData:data
			     encoding:NSISOLatin1StringEncoding];
  [data release]; data = nil;
  
  return [result autorelease];
}

- (NSString *)stringByEscapingImap4Password {
  // TODO: perf
  unichar  *buffer;
  unichar  *chars;
  unsigned len, i, j;
  NSString *s;

  len   = [self length];
  chars = calloc(len + 2, sizeof(unichar));
  [self getCharacters:chars];
  
  buffer = calloc(len * 2 + 2, sizeof(unichar));
  buffer[len * 2] = '\0';
  
  for (i = 0, j = 0; i < len; i++, j++) {
      BOOL conv = NO;
      
      if (chars[i] <= 0x1F || chars[i] > 0x7F) {
        conv = YES;
      }
      else switch (chars[i]) {
        case '(':
        case ')':
        case '{':
        case ' ':
        case '%':
        case '*':
        case '"':
        case '\\':
          conv = YES;
	  break;
      }
      
      if (conv) {
        buffer[j] = '\\';
	j++;
      }
      buffer[j] = chars[i];
  }
  if (chars != NULL) free(chars); chars = NULL;
  
  s = [NSString stringWithCharacters:buffer length:j];
  if (buffer != NULL) free(buffer); buffer = NULL;
  return s;
}

@end /* NSString(Imap4) */

static void writeChunk(int _c1, int _c2, int _c3, int _pads,
                       unsigned char **result_,
                       unsigned int *cntRes_);

static int getChar(int _cnt, int *cnt_, unsigned char *_buf) {
  int result;
  
  if ((_cnt % 2)) {
    result = _buf[*cnt_];
    (*cnt_)++;
  }
  else {
    result = 0;
  }
  return result;
}
static void _encodeToModifiedUTF7(unsigned char *_buf, int encLen,
                                  unsigned char **result_, unsigned int *cntRes_)
{
  int c1, c2, c3;
  int cnt, cntAll;

  cnt    = 0;
  cntAll = 0;

  while (cnt < encLen) {
    c1 = getChar(cntAll++, &cnt, _buf);
    if (cnt == encLen) {
      writeChunk(c1, 0, 0, 2, result_, cntRes_);
    }
    else {
      c2 = getChar(cntAll++, &cnt, _buf);
      if (cnt == encLen) {
        writeChunk(c1, c2, 0, 1, result_, cntRes_);
      }
      else {
        c3 = getChar(cntAll++, &cnt, _buf);
        writeChunk(c1, c2, c3, 0, result_, cntRes_);
      }
    }
  }
}

/* check metamail output for correctness */

static unsigned char basis_64[] =
   "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+,";

static void writeChunk(int c1, int c2, int c3, int pads, unsigned char **result_,
                       unsigned int *cntRes_) {
  unsigned char c;

  c = basis_64[c1>>2];
  (*result_)[*cntRes_] = c;
  (*cntRes_)++;
  
  c = basis_64[((c1 & 0x3)<< 4) | ((c2 & 0xF0) >> 4)];

  (*result_)[*cntRes_] = c;
  (*cntRes_)++;
  
  
  if (pads == 2) {
    ;
  }
  else if (pads) {
    c = basis_64[((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6)];
    (*result_)[*cntRes_] = c;
    (*cntRes_)++;
  }
  else {
    c = basis_64[((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6)];
    
    (*result_)[*cntRes_] = c;
    (*cntRes_)++;
    
    c = basis_64[c3 & 0x3F];
    (*result_)[*cntRes_] = c;
    (*cntRes_)++;
  }
}

static char index_64[128] = {
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,62, 63,-1,-1,-1,
    52,53,54,55, 56,57,58,59, 60,61,-1,-1, -1,-1,-1,-1,
    -1, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
    15,16,17,18, 19,20,21,22, 23,24,25,-1, -1,-1,-1,-1,
    -1,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
    41,42,43,44, 45,46,47,48, 49,50,51,-1, -1,-1,-1,-1
};

#define char64(c)  (((c) < 0 || (c) > 127) ? -1 : index_64[(c)])

static int _decodeOfModifiedUTF7(unsigned char *_target, unsigned _targetLen,
                                 unsigned *usedBytes_ , unsigned char **buffer_,
                                 int *bufLen_, int maxBuf)
{
  int c1, c2, c3, c4;
  unsigned int cnt;
  
  for (cnt = 0; cnt < _targetLen; ) {
    c1 = '=';
    c2 = '=';
    c3 = '=';
    c4 = '=';

    c1 = _target[cnt++];

    if (c1 == '-') {
      (*usedBytes_)++;
      return 0;
    }
    if (cnt < _targetLen)
      c2 = _target[cnt++];

    if (c2 == '-') {
      (*usedBytes_)+=2;
      return 0;
    }
    
    (*usedBytes_) += 2;

    if (cnt < _targetLen) {
      c3 = _target[cnt++];
      (*usedBytes_)++;
    }

    if (cnt < _targetLen) {
      c4 = _target[cnt++];
      if (c3 != '-')
        (*usedBytes_)++;
    }
    
    if (c2 == -1 || c3 == -1 || c4 == -1) {
      fprintf(stderr, "Warning: base64 decoder saw premature EOF!\n");
      return 0;
    }

    if (c1 == '=' || c2 == '=') {
      continue;
    }
    
    c1 = char64(c1);
    c2 = char64(c2);
    
    if (*bufLen_ < maxBuf) {
      unsigned char c;

      c = ((c1<<2) | ((c2&0x30)>>4));

      if (c) {
        (*buffer_)[*bufLen_] = c;
        *bufLen_ = *bufLen_ + 1;
      }
    }
    if (c3 == '-') {
      return 0;
    }
    else if (c3 == '=') {
      continue;
    } else {
      
      c3 = char64(c3);

      if (*bufLen_ < maxBuf) {
        unsigned char c;
        c = (((c2&0XF) << 4) | ((c3&0x3C) >> 2));
        if (c) {
          (*buffer_)[*bufLen_] = c;
          *bufLen_ = *bufLen_ + 1;
        }
      }

      if (c4 == '-') {
        return 0;
      }
      else if (c4 == '=') {
        continue;
      } else {
        c4 = char64(c4);

        if (*bufLen_ < maxBuf) {
          unsigned char c;

          c = (((c3&0x03) <<6) | c4);
          if (c) {
            (*buffer_)[*bufLen_] = c;
            (*bufLen_) = (*bufLen_) + 1;
          }
        }
      }
    }
  }
  return 0;
}
