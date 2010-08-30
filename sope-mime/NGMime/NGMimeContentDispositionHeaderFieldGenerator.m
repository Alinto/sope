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
  
  data = [NSMutableData dataWithCapacity: 64];
  tmp  = [field type];
  [data appendBytes:[tmp cString] length:[tmp length]];
  tmp = [field filename];
  if (tmp != nil) {
    [data appendBytes:"; " length:2];
    [data appendBytes:"filename=\"" length:10];
    
    const char* bytes;
    unsigned length;
    int  cnt;
    BOOL doEnc;

    //d = [tmp dataUsingEncoding: NSUTF8StringEncoding];
    //bytes = [d bytes];
    //length = [d length];
    bytes = [tmp cStringUsingEncoding: NSUTF8StringEncoding];
    length = strlen(bytes);
    
    cnt = 0;
    doEnc = NO;
    while (cnt < length) {
      if ((unsigned char)bytes[cnt] > 127) {
	doEnc = YES;
	break;
      }
      cnt++;
    }

    if (doEnc)
      {
	char        iso[]     = "=?utf-8?q?";
	unsigned    isoLen    = 10;
	char        isoEnd[]  = "?=";
	unsigned    isoEndLen = 2;
	int    desLen;
	char        *des;
	
	desLen = length * 3 + 20;
	
	des = calloc(desLen + 2, sizeof(char));
	
	memcpy(des, iso, isoLen);
	desLen = NGEncodeQuotedPrintableMime((unsigned char *)bytes, length,
					     (unsigned char *)(des + isoLen),
					     desLen - isoLen);
	if (desLen != -1) {
	  memcpy(des + isoLen + desLen, isoEnd, isoEndLen);
	  [data appendBytes:des length:(isoLen + desLen + isoEndLen)];
	}
	else {
          [self logWithFormat:@"WARNING(%s:%i): An error occour during "
		@"quoted-printable decoding",
                __PRETTY_FUNCTION__, __LINE__];
	  if (des != NULL) free(des);
	}
      }
    else
      {
	[data appendBytes:[tmp cString] length:[tmp length]];
      }

    [data appendBytes:"\"" length:1];
  }
  return data;
}
  
@end /* NGMimeContentDispositionHeaderFieldGenerator */
