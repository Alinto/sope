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

#ifndef __NGMimeGenerator_NGMimeBodyGenerator_H__
#define __NGMimeGenerator_NGMimeBodyGenerator_H__

#import <Foundation/NSObject.h>
#import <NGMime/NGPart.h>
#import <NGMime/NGMimeGeneratorProtocols.h>

@class NSData, NSString, NSArray, NGMutableHashMap;
@class NGMimeMultipartBodyGenerator, NGMimeMultipartBody;

@interface NGMimeBodyGenerator : NSObject <NGMimeBodyGenerator>
{
  BOOL useMimeData;
}
- (NSData *)generateBodyOfPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders
  delegate:(id)_delegate;

- (NSData *)encodeData:(NSData *)_data
  forPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders;

- (BOOL)useMimeData;
- (void)setUseMimeData:(BOOL)_b;
@end

@interface NGMimeTextBodyGenerator : NGMimeBodyGenerator
@end

@interface NGMimeRfc822BodyGenerator : NGMimeBodyGenerator

- (id<NGMimePartGenerator>)generatorForPart:(id<NGMimePart>)_part;

@end

@interface NGMimeMultipartBodyGenerator : NGMimeBodyGenerator

+ (NSString *)boundaryPrefix;

- (NSString *)multipartBodyGenerator:(NGMimeMultipartBodyGenerator *)_gen
  prefixForPart:(id<NGMimePart>)_part
  mimeMultipart:(NGMimeMultipartBody *)_body;
  
- (NSString *)multipartBodyGenerator:(NGMimeMultipartBodyGenerator *)_gen
  suffixForPart:(id<NGMimePart>)_part
  mimeMultipart:(NGMimeMultipartBody *)_body;
  
- (id<NGMimePartGenerator>)multipartBodyGenerator:(NGMimeBodyGenerator *)_gen
  generatorForPart:(id<NGMimePart>)_part;

- (NSData *)buildDataWithBoundary:(NSString *)_boundary
  partsData:(NSArray *)_parts;

- (NSString *)buildBoundaryForPart:(id<NGMimePart>)_part data:(NSArray *)_data
  additionalHeaders:(NGMutableHashMap *)_addHeaders; 
  
@end

#endif // __NGMimeGenerator_NGMimeBodyGenerator_H__
