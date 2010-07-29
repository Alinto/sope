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

#ifndef __NGMime_NGPart_H__
#define __NGMime_NGPart_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

/*
  NGPart / NGMimePart
  
  Represents a MIME part, that is, a data block with associated header fields.
*/

@class NSEnumerator, NSString, NSArray;
@class NGMimeType;

@protocol NGPart < NSObject >

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name;
- (NSEnumerator *)headerFieldNames;

- (void)setBody:(id)_body;
- (id)body;

@end

@protocol NGMimePart < NGPart >

- (NGMimeType *)contentType;   // the content-type
- (NSString *)contentId;       // get the Content-ID of this part
- (NSArray *)contentLanguage;  // get the language tags from Content-Language
- (NSString *)contentMd5;      // get the Content-MD5 digest of this part
- (NSString *)encoding;        // get the transfer encoding of this part

@end

@interface NSData(DataPart) < NGMimePart >
@end

#endif /* __NGMime_NGPart_H__ */
