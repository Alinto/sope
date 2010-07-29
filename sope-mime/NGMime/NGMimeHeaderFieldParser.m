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

#include "NGMimeHeaderFieldParser.h"
#include "NGMimeHeaderFields.h"
#include "NGMimeUtilities.h"
#include "common.h"
#include <NGMime/NGMimePartParser.h>

@implementation NGMimeHeaderFieldParser

static int MimeLogEnabled     = -1;
static int StripLeadingSpaces = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (MimeLogEnabled == -1)
    MimeLogEnabled = [ud boolForKey:@"MimeLogEnabled"]?1:0;
  if (StripLeadingSpaces == -1)
    StripLeadingSpaces = [ud boolForKey:@"StripLeadingSpaces"]?1:0;
}
+ (BOOL)isMIMELogEnabled {
  return MimeLogEnabled ? YES : NO;
}
+ (BOOL)doesStripLeadingSpaces {
  return StripLeadingSpaces ? YES : NO;
}

+ (int)version {
  return 2;
}

- (NSString *)removeCommentsFromValue:(NSString *)_rawValue {
  unsigned int len = [_rawValue length];
  unichar      bytes[len + 1];
  unsigned int cnt;
  NSString     *str;

  if (_rawValue == NULL) return nil;

  [_rawValue getCharacters:bytes];
  bytes[len] = '\0';
  cnt   = 0;
  str   = nil;

  while ((cnt < len) && (bytes[cnt] != '(')) cnt++;
  
  if (cnt < len) {
    unichar  result[len+1];
    int      resLen, commentNesting, begin;
    BOOL     modifyValue;

    resLen         = 0;
    commentNesting = 0;
    begin          = 0;
    modifyValue    = NO;
    
    for (cnt = 0; cnt < len; cnt++) {
      if (commentNesting == 0) {
        if (isRfc822_QUOTE(bytes[cnt])) {
          cnt++;
          while ((cnt < len) && !isRfc822_QUOTE(bytes[cnt]))
            cnt++;
        }
        else if (bytes[cnt] == '(') {
          modifyValue = YES;
          
          if ((cnt - begin) > 0) {
            int c;

            for (c = begin; c < cnt; c++) 
              result[resLen++]  = bytes[c];
          }
          commentNesting++;
        }
      }
      else {
        if (bytes[cnt] == ')') {
          commentNesting--;
          if (commentNesting == 0)
            begin = (cnt + 1);
        }
        else if (bytes[cnt] == '(')
          commentNesting++;
      }
    }
    if (modifyValue) {
      if ((cnt - begin) > 0) {
        int c;

        for (c = begin; c < cnt; c++)
          result[resLen++]  = bytes[c];
      }
      str = [[[NSString alloc] initWithCharacters:result length:resLen]
                        autorelease];
    }
  }
  if (str == nil)
    str = _rawValue;

  if (MimeLogEnabled) {
    if (str != _rawValue) {
      [self logWithFormat:@"%s:%d remove comment [%@] -> [%@]",
            __PRETTY_FUNCTION__, __LINE__, _rawValue, str];
    }
  }
  return str;
}

- (NSData *)quotedPrintableDecoding:(NSData *)_value {
  return _value;
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field { 
  // abstract
  NSLog(@"ERROR(%s): subclass should override this method: %@",
	__PRETTY_FUNCTION__, self);
  return nil;
}

@end /* NGMimeHeaderFieldParser */
