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

#ifndef __NGExtensions_NGBase64Encoding_H__
#define __NGExtensions_NGBase64Encoding_H__

#import <Foundation/NSString.h>
#import <Foundation/NSData.h>

/*
  Base64 encoder/decoder

  Attention: these methods/function do _not_ generate a '\n' at the end of
             the end of encoding (after the '=' signs).

  The NSString and NSData have their own maximum line length, for strings
  it is currently 1024 bytes and for data's 72 chars.
*/

@interface NSString(Base64Coding)

- (NSString *)stringByEncodingBase64;
- (NSString *)stringByDecodingBase64;
- (NSData *)dataByDecodingBase64;

@end

@interface NSData(Base64Coding)

- (NSData *)dataByEncodingBase64; /* Note: inserts '\n' every 72 chars */
- (NSData *)dataByDecodingBase64;
- (NSString *)stringByEncodingBase64;
- (NSString *)stringByDecodingBase64;

- (NSData *)dataByEncodingBase64WithLineLength:(unsigned)_lineLength;

@end

/*
  These function return the length of the resulting buffer or -1 on error
*/
int NGEncodeBase64(const void *_source, unsigned _len,
                   void *_buffer, unsigned _bufferCapacity,
                   int _maxLineWidth);
int NGDecodeBase64(const void *_source, unsigned _len,
                   void *_buffer, unsigned _bufferCapacity);

#endif /* __NGExtensions_NGBase64Encoding_H__ */
