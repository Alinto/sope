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

#include "NGMimeMessageGenerator.h"
#include "NGMimeMessage.h"
#include <NGMime/NGMimeFileData.h>
#include "common.h"

/* Defaults
  Mail_Use_8bit_Encoding_For_Text[BOOL] --
    Use 8bit content-transfer-encoding for
    text messages
*/

NSData *
_base64Encoding(NGMimeBodyGenerator *self,
                NSData *_data_,
                id<NGMimePart>_part,
                NGMutableHashMap *_addHeaders)
{
  NSString   *transEnc = nil;  
  const char *bytes    = NULL;
  unsigned   length    = 0;
  
  /* kinda hack, treat NGMimeFileData objects as already encoded */
  
  if ([_data_ isKindOfClass:[NGMimeFileData class]])
    return _data_;

  /* encoding */
  
  bytes  = [_data_ bytes];
  length = [_data_ length];

  while (length > 0) {
    if ((unsigned char)*bytes > 127) {
      break;
    }
    bytes++;
    length--;
  }
  if (length > 0) { // should be encoded
    NGMimeType *type;

    type = [_part contentType];
    
    if ([[type type] isEqualToString:@"text"]) {
      NSUserDefaults *ud;
      BOOL use8bit;

      ud      = [NSUserDefaults standardUserDefaults];
      use8bit = [ud boolForKey:@"Mail_Use_8bit_Encoding_For_Text"];
      
      if (use8bit)
        transEnc = @"8bit";
      else {
        _data_   = [_data_ dataByEncodingQuotedPrintable];
        transEnc = @"quoted-printable";
      }
    }
    else {
      NGMimeType *appOctet;
      
      _data_   = [_data_ dataByEncodingBase64];
      transEnc = @"base64";

      appOctet = [NGMimeType mimeType:@"application" subType:@"octet-stream"];
      if (type == nil)
        [_addHeaders setObject:appOctet forKey:@"content-type"];
    }
  }
  else /* no encoding */
    transEnc = @"7bit";
  
  [_addHeaders setObject:transEnc forKey:@"content-transfer-encoding"];
  [_addHeaders setObject:[NSNumber numberWithInt:[_data_ length]]
                      forKey:@"content-length"];
  return _data_;
}
