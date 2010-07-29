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
  NSData	*valueData;
  
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
  valueData = [tmp dataUsingEncoding: NSISOLatin1StringEncoding];
  [data appendData: valueData];

  [data appendBytes:"/" length:1];
  
  tmp = [type subType];
  if (tmp != nil) {
    valueData = [tmp dataUsingEncoding: NSISOLatin1StringEncoding];
    [data appendData:valueData];
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
  
      valueData = [name dataUsingEncoding: NSUTF8StringEncoding];
      [data appendData: valueData];

      /*
        this confuses GroupWise: "= \"" (a space)
      */
      [data appendBytes:"=\"" length:2];

      /* check for encoding */
      {
        unsigned cnt, max;
	const char *dataBytes;
        BOOL doEnc;
        
	valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
	dataBytes = [valueData bytes];
	max = [valueData length];

        doEnc = NO;
        cnt  = 0;
        while (!doEnc && cnt < max) {
          if ((unsigned char)dataBytes[cnt] > 127)
            doEnc = YES;
	  else
	    cnt++;
        }
        if (doEnc) {
	  [data appendBytes:"=?utf-8?q?" length:10];
	  [data appendData: [valueData dataByEncodingQuotedPrintable]];
	  [data appendBytes:"?=" length:2];
        }
        else {
	  [data appendData: valueData];
        }
      }
      [data appendBytes:"\"" length:1];      
    }
  }
  return data;
}

@end /* NGMimeContentTypeHeaderFieldGenerator */
