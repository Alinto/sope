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

#ifndef __NGMail_NGMimeMessage_H__
#define __NGMail_NGMimeMessage_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGPart.h>

@class NGHashMap;

/*
  NGMimeMessage represents a RFC822 message with MIME extensions.
*/

@class NSString, NSArray, NSDictionary, NSEnumerator;
@class NGHashMap;
@class NGMimeType;

@interface NGMimeMessage : NSObject < NGMimePart >
{
@protected
  NGHashMap  *header;
  id         body;
  NGMimeType *mimeType;
}

+ (id)messageWithHeader:(NGHashMap *)_headers;
- (id)initWithHeader:(NGHashMap *)_headers; // designated initializer

/* NGPart */

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name;
- (NSEnumerator *)headerFieldNames;

- (void)setBody:(id)_body;
- (id)body;

/* NGMimePart */

- (NGMimeType *)contentType;
- (NSString *)contentId;
- (NSArray *)contentLanguage;
- (NSString *)contentMd5;
- (NSString *)encoding;
- (NSString *)contentDescription;

/* convenience */

- (NSString *)headerForKey:(NSString *)_key;
- (NSArray *)headersForKey:(NSString *)_key;
- (NSArray *)headerKeys;
- (NSDictionary *)headers;
- (NSString *)headersAsString;

@end

#endif /* __NGMail_NGMimeMessage_H__ */
