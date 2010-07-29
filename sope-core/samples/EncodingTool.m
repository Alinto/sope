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

#import "EncodingTool.h"
#import "common.h"
#import <NGStreams/NGStreams.h>
#import <NGMime/NGMime.h>
#import <NGMail/NGMail.h>

@implementation EncodingTool

- (NSUserDefaults *)userDefaults {
  return [NSUserDefaults standardUserDefaults];
}


- (BOOL)getEncoding:(NSString *)_encodingStr
  encoding:(NSStringEncoding *)_encoding
{
  NSLog(@"_encoding %@", _encodingStr);
  if ([_encodingStr isEqualToString:@"NSASCIIStringEncoding"])
    *_encoding = NSASCIIStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSNEXTSTEPStringEncoding"])
    *_encoding = NSNEXTSTEPStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSJapaneseEUCStringEncoding"])
    *_encoding = NSJapaneseEUCStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSUTF8StringEncoding"])
    *_encoding = NSUTF8StringEncoding;
  else if ([_encodingStr isEqualToString:@"NSISOLatin1StringEncoding"])
    *_encoding = NSISOLatin1StringEncoding;
  else if ([_encodingStr isEqualToString:@"NSSymbolStringEncoding"])
    *_encoding = NSSymbolStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSNonLossyASCIIStringEncoding"])
    *_encoding = NSNonLossyASCIIStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSShiftJISStringEncoding"])
    *_encoding = NSShiftJISStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSISOLatin2StringEncoding"])
    *_encoding = NSISOLatin2StringEncoding;
  else if ([_encodingStr isEqualToString:@"NSUnicodeStringEncoding"])
    *_encoding = NSUnicodeStringEncoding;
#if LIB_FOUNDATION_LIBRARY
  else if ([_encodingStr isEqualToString:@"NSISOLatin9StringEncoding"])
    *_encoding = NSISOLatin9StringEncoding;
  else if ([_encodingStr isEqualToString:@"NSAdobeStandardCyrillicStringEncoding"])
    *_encoding = NSAdobeStandardCyrillicStringEncoding;
  else if ([_encodingStr isEqualToString:@"NSWinLatin1StringEncoding"])
    *_encoding = NSWinLatin1StringEncoding;
#endif
  else {
    NSLog(@"%s: could not find encoding: '%@'",
          __PRETTY_FUNCTION__, _encodingStr);
    return NO;
  }
  return YES;
}

- (void)processEncoding {
  NSData   *data;
  NSString *str;

  data = [NSData dataWithContentsOfFile:self->file];

  NSLog(@"%s: got data %s", __PRETTY_FUNCTION__, [data bytes]);

  str = [[[NSString alloc] initWithData:data encoding:self->fromEncoding]
                    autorelease];
  NSLog(@"%s: str length %d str %s ", __PRETTY_FUNCTION__, [str length], [str cString]);
  data = [str dataUsingEncoding:self->toEncoding];
  NSLog(@"%s: data length %d str %s ", __PRETTY_FUNCTION__, [data length], [data bytes]);
  
}

/* tool operation */

- (int)usage {
  fprintf(stderr, "usage: encoding <file>\n");
  fprintf(stderr, "  -from_encoding  <s>\n");
  fprintf(stderr, "  -to_encoding    <s>\n");
  return 1;
}

- (int)runWithArguments:(NSArray *)_args {
  NSUserDefaults *ud = [self userDefaults];
  NSString *tmp;
  
  _args = [_args subarrayWithRange:NSMakeRange(1, [_args count] - 1)];
  if ([_args count] == 0)
    return [self usage];

  self->file = [_args lastObject];

  tmp = [ud stringForKey:@"from_encoding"];
  if ([tmp length]) {
    if (![self getEncoding:tmp encoding:&self->fromEncoding])
      self->fromEncoding = [NSString defaultCStringEncoding];
  }
  else
    self->fromEncoding = [NSString defaultCStringEncoding];

  tmp = [ud stringForKey:@"to_encoding"];
  if ([tmp length]) {
    if (![self getEncoding:tmp encoding:&self->toEncoding])
      self->toEncoding = [NSString defaultCStringEncoding];
  }
  else
    self->toEncoding = [NSString defaultCStringEncoding];

  NSLog(@"process file %@ with from-encoding %@ to encoding %@",
        file, [NSString localizedNameOfStringEncoding:self->fromEncoding],
        [NSString localizedNameOfStringEncoding:self->toEncoding]);

  [self processEncoding];
  
  return 0;
}

@end /* Mime2XmlTool */
