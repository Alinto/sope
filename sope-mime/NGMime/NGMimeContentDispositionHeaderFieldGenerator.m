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
#include <string.h>

@implementation NGMimeContentDispositionHeaderFieldGenerator

+ (int)version {
  return 2;
}

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  NGMimeContentDispositionHeaderField *field;
  NSString      *tmp;
  NSMutableData *data;
  
  field = _value;
  if (field == nil) {
    [self logWithFormat:@"WARNING(%s): Content-Disposition field is empty",
          __PRETTY_FUNCTION__];
    return [NSData data];
  }
  
  if ([_value isKindOfClass:[NSString class]])
    return [_value dataUsingEncoding:NSUTF8StringEncoding];
  
  // TODO: move the stuff below to some NSString or NSData category?
  
  data = [NSMutableData dataWithCapacity:64];
  tmp  = [field type];
  [data appendBytes:[tmp cString] length:[tmp length]];
  tmp = [field filename];
  if (tmp != nil) {
    [data appendBytes:"; " length:2];
    [data appendBytes:"filename=\"" length:10];
    {
      unsigned char *ctmp;
      int  cnt, len;
      BOOL doEnc;
      
      // TODO: unicode?
      len  = [tmp cStringLength];
      ctmp = malloc(len + 3);
      [tmp getCString:(char *)ctmp]; ctmp[len] = '\0';
      cnt  = 0;
      doEnc = NO;
      while (cnt < len) {
        if ((unsigned char)ctmp[cnt] > 127) {
          doEnc = YES;
          break;
        }
        cnt++;
      }
      if (doEnc) {
        char        iso[]     = "=?iso-8859-15?q?";
        unsigned    isoLen    = 16;
        char        isoEnd[]  = "?=";
        unsigned    isoEndLen = 2;
        unsigned    desLen;
        char        *des;
      
        if (ctmp) free(ctmp);
        {
          NSData *data;

#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
          data = [tmp dataUsingEncoding:NSISOLatin1StringEncoding];
#else
          data = [tmp dataUsingEncoding:NSISOLatin9StringEncoding];
#endif

          len  = [data length];
          ctmp =  malloc(len+1);
          [data getBytes:ctmp];  ctmp[len] = '\0';
        }
          
        desLen = len * 3 + 20;
        des    = calloc(desLen + 10, sizeof(char));
      
        memcpy(des, ctmp, cnt);
        memcpy(des + cnt, iso, isoLen);
        desLen =
	  NGEncodeQuotedPrintableMime((unsigned char *)ctmp + cnt, len - cnt,
				      (unsigned char *)des + cnt + isoLen,
				      desLen - cnt - isoLen);
        if ((int)desLen != -1) {
          memcpy(des + cnt + isoLen + desLen, isoEnd, isoEndLen);
          [data appendBytes:des length:(cnt + isoLen + desLen + isoEndLen)];
        }
        else {
          [self logWithFormat:@"WARNING(%s:%i): An error occour during "
		@"quoted-printable decoding",
                __PRETTY_FUNCTION__, __LINE__];
        }
        if (des) free(des);
      }
      else {
        [data appendBytes:ctmp length:len];
      }
    }
      //      [data appendBytes:[tmp cString] length:[tmp length]];
      [data appendBytes:"\"" length:1];
  }
  return data;
}
  
@end /* NGMimeContentDispositionHeaderFieldGenerator */
