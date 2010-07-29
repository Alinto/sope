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
#include <NGMime/NGMimePartParser.h>
#include "common.h"
#include <string.h>

#if MOVED_TO_NGMAIL
#  include <NGMail/NGMailAddressParser.h>
#else
@interface NSObject(MailAddressParser)
+ (id)mailAddressParserWithString:(NSString *)_string;
+ (id)mailAddressParserWithData:(NSData *)_data;
- (id)parseAddressList;
@end
#endif

@interface NSObject(UsedProtocols)
- (NSString *)displayName; // hh: where is that implemented ?
@end

@implementation NGMimeAddressHeaderFieldGenerator

static int UseLFSeperatedAddressEntries = -1;

+ (int)version {
  return 2;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  if (UseLFSeperatedAddressEntries == -1) {
    id o;

    if ((o = [ud objectForKey:@"UseLFSeperatedAddressEntries"]))
      UseLFSeperatedAddressEntries = [o boolValue]?1:0;
    else
      UseLFSeperatedAddressEntries = 1;
  }
}

/* operation */

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value
{
  // TODO: produces a reference to NGMailAddressParser which is in NGMail!
#if MOVED_TO_NGMAIL
  NGMailAddressParser *parser;
#else
  id parser;
#endif
  NSMutableString     *result;
  NSData              *data;
  id                  obj;
  NSEnumerator        *enumerator;
  
#if MOVED_TO_NGMAIL
  parser = ([_value isKindOfClass:[NSString class]])
    ? [NGMailAddressParser mailAddressParserWithString:_value]
    : [NGMailAddressParser mailAddressParserWithData:_value];
#else
  parser = ([_value isKindOfClass:[NSString class]])
    ? [NSClassFromString(@"NGMailAddressParser")
			mailAddressParserWithString:_value]
    : [NSClassFromString(@"NGMailAddressParser")
			mailAddressParserWithData:_value];
#endif
  
  enumerator = [[parser parseAddressList] objectEnumerator];
  result     = [[NSMutableString alloc] initWithCapacity:128];
  
  while ((obj = [enumerator nextObject]) != nil) {
    NSString   *tmp;
    char       *buffer;
    unsigned   bufLen, cnt;
    BOOL       doEnc;
    
    if ([result length] > 0) {
      if (UseLFSeperatedAddressEntries == 1)
        [result appendString:@",\n   "];
      else
        [result appendString:@", "];
    }
    
    tmp    = [obj displayName];
    bufLen = [tmp cStringLength];
    
    buffer = calloc(bufLen + 10, sizeof(char));
    [tmp getCString:buffer];
    
    cnt   = 0;
    doEnc = NO;
    
    while (cnt < bufLen) {
      /* must encode chars outside ASCII 33..60, 62..126 ranges [RFC 2045, Sect. 6.7]
       * RFC 2047, Sect. 4.2 also requires chars 63 and 95 to be encoded
       * For spaces, quotation is fine */
      if ((unsigned char)buffer[cnt] < 32 ||
	  (unsigned char)buffer[cnt] == 61 ||
	  (unsigned char)buffer[cnt] == 63 ||
          (unsigned char)buffer[cnt] == 95 ||
	  (unsigned char)buffer[cnt] > 126) {
        doEnc = YES;
        break;
      }
      cnt++;
    }
    
    if (doEnc) {
      /* FIXME - better use UTF8 encoding! */
      unsigned char iso[]     = "=?iso-8859-15?q?";
      unsigned      isoLen    = 16;
      unsigned char isoEnd[]  = "?=";
      unsigned      isoEndLen = 2;
      unsigned      desLen;
      unsigned char *des;
      
      if (buffer != NULL) free(buffer); buffer = NULL;
      {
        NSData *data;

#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
        data = [tmp dataUsingEncoding:NSISOLatin1StringEncoding];
#else
        data = [tmp dataUsingEncoding:NSISOLatin9StringEncoding];
#endif

        bufLen  = [data length];
        buffer =  malloc(bufLen + 10);
        [data getBytes:buffer];  buffer[bufLen] = '\0';
      }
          
      desLen = bufLen * 3 + 20;
      des    = calloc(desLen + 10, sizeof(char));
      
      memcpy(des, iso, isoLen);
      memcpy(des + isoLen, buffer, bufLen);
      desLen =
        NGEncodeQuotedPrintableMime((unsigned char *)buffer, bufLen,
                                    des + isoLen, desLen - isoLen);
      if ((int)desLen != -1) {
        memcpy(des + isoLen + desLen, isoEnd, isoEndLen);
        tmp = [NSString stringWithCString:(char *)des
                        length:(isoLen + desLen + isoEndLen)];
      }
      else {
        [self warnWithFormat:
		@"%s:%i: An error occour during quoted-printable decoding",
	        __PRETTY_FUNCTION__, __LINE__];
      }
      if (des) free(des);
    }
    if (buffer) free(buffer); buffer = NULL;

    if ([tmp length] > 0) {
      /* do not place encoded strings in quotes [RFC 2045, RFC 2047, RFC 2822] */
      if (!doEnc) [result appendString:@"\""];
      [result appendString:tmp];
      if (!doEnc) [result appendString:@"\""];
      if ((tmp = [(NSHost *)obj address])) {
        [result appendString:@" <"];
        [result appendString:tmp];
        [result appendString:@">"];
      }
    }
    else if ((tmp = [(NSHost *)obj address])) {
      [result appendString:tmp];
    }
  }
  
#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  data = [result dataUsingEncoding:NSISOLatin1StringEncoding];
#else
  data = [result dataUsingEncoding:NSISOLatin9StringEncoding];
#endif
  [result release];
  
  return data;
}

@end /* NGMimeAddressHeaderFieldGenerator */
