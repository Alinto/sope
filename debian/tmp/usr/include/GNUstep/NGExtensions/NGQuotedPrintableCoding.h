/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#ifndef __NGExtensions_NGQuotedPrintableCoding_H__
#define __NGExtensions_NGQuotedPrintableCoding_H__

#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#include <NGExtensions/NGExtensionsDecls.h>

/*
  Quoted Printable encoder/decoder

  As specified in RFC 822 / 2045 / 2047. Note that 2045 and 2047 specify
  different variants (Q vs content-transfer-encoding)

  TODO: explain what it does. It doesn't seem to decode a full line like
          "=?iso-8859-1?q?Yannick=20DAmboise?="
        but only turns "=20D" style encodings to their charcode.
	
  Note: apparently sope-mime contains a category on NSData which provides a
        method to decode the full value:
          -decodeQuotedPrintableValueOfMIMEHeaderField:
        (NGMimeMessageParser)
*/

@interface NSData(QuotedPrintableCoding)

/*
  Decode a quoted printable encoded data. Returns nil if decoding failed. The
  first method does the RFC 2047 variant, the second RFC 2045 (w/o _ replacing)
*/
- (NSData *)dataByDecodingQuotedPrintable;
- (NSData *)dataByDecodingQuotedPrintableTransferEncoding;

/*
  Decode data in quoted printable encoding. Returns nil if encoding failed.
*/
- (NSData *)dataByEncodingQuotedPrintable;

@end


/* Note: you should avoid NSString methods for QP, its defined on byte level */
@interface NSString(QuotedPrintableCoding)

- (NSString *)stringByDecodingQuotedPrintable;
- (NSString *)stringByEncodingQuotedPrintable;

@end


NGExtensions_EXPORT int
NGEncodeQuotedPrintable(const char *_src, unsigned _srcLen,
                        char *_dest, unsigned _destLen);
NGExtensions_EXPORT int
NGDecodeQuotedPrintable(const char *_src, unsigned _srcLen,
                        char *_dest, unsigned _destLen);
NGExtensions_EXPORT int
NGDecodeQuotedPrintableX(const char *_src, unsigned _srcLen,
			 char *_dest, unsigned _destLen,
			 BOOL _replaceUnderline);

#endif /* __NGExtensions_NGQuotedPrintableCoding_H__ */
