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

#ifndef __NGMime_NGMimeType_H__
#define __NGMime_NGMimeType_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#include <NGMime/NGMimeDecls.h>

@class NSDictionary, NSString, NSEnumerator;

// type & parameter constants

NGMime_EXPORT NSString *NGMimeTypeText;
NGMime_EXPORT NSString *NGMimeTypeAudio;
NGMime_EXPORT NSString *NGMimeTypeVideo;
NGMime_EXPORT NSString *NGMimeTypeImage;
NGMime_EXPORT NSString *NGMimeTypeApplication;
NGMime_EXPORT NSString *NGMimeTypeMultipart;
NGMime_EXPORT NSString *NGMimeTypeMessage;

NGMime_EXPORT NSString *NGMimeParameterTextCharset;

/*
  NGMimeType is a class cluster
*/

@interface NGMimeType : NSObject < NSCoding, NSCopying >
{
}

+ (id)mimeType:(NSString *)_type subType:(NSString *)_subType;
+ (id)mimeType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters;

+ (id)mimeType:(NSString *)_stringValue;

+ (NSStringEncoding)stringEncodingForCharset:(NSString *)_s;

/* type */

- (NSString *)type;
- (NSString *)subType;
- (BOOL)isCompositeType;

/* comparing types */

- (BOOL)isEqualToMimeType:(NGMimeType *)_type;
- (BOOL)isEqual:(id)_other;
- (BOOL)hasSameGeneralType:(NGMimeType *)_other; // only the 'type' must match
- (BOOL)hasSameType:(NGMimeType *)_other;        // parameters need not match
- (BOOL)doesMatchType:(NGMimeType *)_other;      // interpretes wildcards

// parameters

- (NSEnumerator *)parameterNames;
- (id)valueOfParameter:(NSString *)_parameterName;

// representations

- (NSDictionary *)parametersAsDictionary;
- (NSString *)parametersAsString;
- (BOOL)valueNeedsQuotes:(NSString *)_parameterValue;

- (NSString *)stringValue;

@end

#endif /* __NGMime_NGMimeType_H__ */
