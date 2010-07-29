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

@implementation NGMimeContentTypeHeaderFieldGenerator

+ (int)version {
  return 2;
}

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  NGMimeType    *type = nil; // only one content-type field
  NSString      *tmp  = nil;
  NSMutableData *data = nil;
  unsigned char *ctmp = NULL;
  unsigned      len   = 0;
  
  type = _value;

  if (type == nil) {
    NSLog(@"WARNING(%s): empty content type field", __PRETTY_FUNCTION__);
    return [NSData dataWithBytes:"application/octet-stream" length:24];
  }
  if ([_value isKindOfClass:[NSString class]]) {
    return [_value dataUsingEncoding:NSUTF8StringEncoding];
  }
  
  if (![type isKindOfClass:[NGMimeType class]]) {
    NSLog(@"WARNING(%s): invalid MIME type value (%@) !", __PRETTY_FUNCTION__,
          type);
    return [NSData dataWithBytes:"application/octet" length:24];
  }
  
  data = [NSMutableData dataWithCapacity:64];
  
  tmp = [type type];
  NSAssert(tmp, @"type should not be nil");
  len  = [tmp length];
  ctmp = malloc(len + 4);
  [tmp getCString:(char *)ctmp]; ctmp[len] = '\0';
  [data appendBytes:ctmp length:len];
  free(ctmp);
  
  [data appendBytes:"//" length:1];
  
  tmp = [type subType];
  if (tmp != nil) {
    len  = [tmp length];
    ctmp = malloc(len + 4);
    [tmp getCString:(char *)ctmp]; ctmp[len] = '\0';
    [data appendBytes:ctmp length:len];
    free(ctmp);
  }
  else
    [data appendBytes:"*" length:1];

  {  // parameters
    NSEnumerator *enumerator = [type parameterNames];
    NSString     *name       = nil;
    NSString     *value      = nil;
    
    while ((name = [enumerator nextObject])) {
      value = [type valueOfParameter:name];
      if (![value isKindOfClass:[NSString class]]) {
        NSLog(@"ERROR[%s]: parameter should be a NSString headerField: %@ "
              @"value %@", __PRETTY_FUNCTION__, _headerField, _value);
        continue;
      }
      [data appendBytes:"; " length:2];
      
      len  = [name cStringLength];
      ctmp = malloc(len + 1);
      [name getCString:(char *)ctmp]; ctmp[len] = '\0';
      [data appendBytes:ctmp length:len];
      free(ctmp);

      /*
        this confuses GroupWise: "= \"" (a space)
      */
      [data appendBytes:"=\"" length:2];

      /* check for encoding */
      {
        unsigned cnt;
        BOOL doEnc;
        
        len  = [value cStringLength];
        ctmp = malloc(len + 4);
        [value getCString:(char *)ctmp]; ctmp[len] = '\0';
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
          unsigned char iso[]     = "=?iso-8859-15?q?";
          unsigned      isoLen    = 16;
          unsigned char isoEnd[]  = "?=";
          unsigned      isoEndLen = 2;
          unsigned      desLen;
          unsigned char *des;
	  
          if (ctmp) free(ctmp);
          {
            NSData *data;

#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
            data = [value dataUsingEncoding:NSISOLatin1StringEncoding];
#else
            data = [value dataUsingEncoding:NSISOLatin9StringEncoding];
#endif

            len  = [data length];
            ctmp =  malloc(len + 10);
            [data getBytes:ctmp];  ctmp[len] = '\0';
          }
          
          desLen = len * 3 + 20;
          des    = calloc(desLen + 10, sizeof(char));
      
          memcpy(des, ctmp, cnt);
          memcpy(des + cnt, iso, isoLen);
          desLen =
               NGEncodeQuotedPrintableMime(ctmp + cnt, len - cnt,
                                           des + cnt + isoLen,
                                           desLen - cnt - isoLen);
          if ((int)desLen != -1) {
            memcpy(des + cnt + isoLen + desLen, isoEnd, isoEndLen);
            [data appendBytes:des length:(cnt + isoLen + desLen + isoEndLen)];
          }
          else {
            NSLog(@"WARNING: An error occour during quoted-printable decoding");
          }
          if (des) free(des);
        }
        else {
          [data appendBytes:ctmp length:len];
        }
          free(ctmp);
      }
      [data appendBytes:"\"" length:1];      
    }
  }
  return data;
}

@end /* NGMimeContentTypeHeaderFieldGenerator */
