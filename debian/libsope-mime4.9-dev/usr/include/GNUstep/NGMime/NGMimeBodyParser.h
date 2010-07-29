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

#ifndef __NGMime_NGMimeBodyParser_H__
#define __NGMime_NGMimeBodyParser_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGPart.h>

@class NSData;

@protocol NGMimeBodyParser < NSObject >

- (id)parseBodyOfPart:(id<NGMimePart>)_part
  data:(NSData *)_data
  delegate:(id)_delegate;

@end

@interface NGMimeBodyParser : NSObject < NGMimeBodyParser >
@end

@interface NGMimeTextBodyParser : NGMimeBodyParser
@end

@class NGMimePartParser;
@class NGMimeMultipartBody;

/*
  A multipart body is a part body that contains body-parts separated
  by boundary lines.
*/
@interface NGMimeMultipartBodyParser : NGMimeBodyParser

- (BOOL)parseBody:(NGMimeMultipartBody *)_body
  ofMultipart:(id<NGMimePart>)_part
  data:(NSData *)_data
  delegate:(id)_d;

- (id<NGMimePart>)parseBodyPartWithData:(NSData *)_rawData
  inMultipart:(id<NGMimePart>)_multipart
  parser:(NGMimePartParser *)_parser; // usually a NGMimeBodyPartParser

@end

@interface NSObject(NGMimeMultipartBodyParserDelegate)

- (BOOL)multipartBodyParser:(NGMimeMultipartBodyParser *)_parser
  immediatlyParseBodyOfMultipart:(id<NGMimePart>)_part
  data:(NSData *)_data;

- (void)multipartBodyParser:(NGMimeMultipartBodyParser *)_parser
  foundPrefix:(NSData *)_prefix
  inMultipart:(id<NGMimePart>)_part;

- (void)multipartBodyParser:(NGMimeMultipartBodyParser *)_parser
  foundSuffix:(NSData *)_suffix
  inMultipart:(id<NGMimePart>)_part;

- (NGMimePartParser *)multipartBodyParser:(NGMimeMultipartBodyParser *)_parser
  parserForEntity:(NSData *)_data
  inMultipart:(id<NGMimePart>)_part;

@end

#endif /* __NGMime_NGMimeBodyParser_H__ */
