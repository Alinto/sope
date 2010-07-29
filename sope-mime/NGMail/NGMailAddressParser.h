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

#ifndef __NGMail_NGMailAddressParser_H__
#define __NGMail_NGMailAddressParser_H__

#import <Foundation/NSObject.h>

@class NSData, NSString, NSArray;
@class NGMailAddressList;

/*
  use RFC 822
*/

@interface NGMailAddressParser : NSObject
{
@private
  unsigned char *data;
  int           dataPos;
  int           errorPos;  
  int           maxLength;
}

+ (id)mailAddressParserWithString:(NSString *)_string;
+ (id)mailAddressParserWithData:(NSData *)_data;
+ (id)mailAddressParserWithCString:(char *)_cString;
- (id)initWithCString:(const unsigned char *)_cstr length:(int unsigned)_len;

/* parsing */

- (id)parse; // returns NGMailAddressList/NGMailAddress or nil on error
- (NSArray *)parseAddressList;

/* error information */

- (int)errorPosition;

@end

#endif /* __NGMail_NGMailAddressParser_H__ */
