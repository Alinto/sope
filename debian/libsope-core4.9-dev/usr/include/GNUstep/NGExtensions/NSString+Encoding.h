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

#ifndef __NGExtensions_NSString_Encoding_H__
#define __NGExtensions_NSString_Encoding_H__

#import <Foundation/NSString.h>

/*
  NSString(Encoding)
  
  TODO: handler is currently fixed to iconv, should allow a registry of
        handlers
*/

@interface NSString(Encoding)

+ (NSString *)stringWithData:(NSData *)_da usingEncodingNamed:(NSString *)_enc;
- (NSData *)dataUsingEncodingNamed:(NSString *)_encoding;

+ (NSStringEncoding)stringEncodingForEncodingNamed:(NSString *)encoding;

@end

#endif /* __NGExtensions_NSString_Encoding_H__ */

