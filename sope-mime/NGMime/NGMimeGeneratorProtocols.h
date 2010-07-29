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

#ifndef __NGMimeGenerator_NGMimeGeneratorProtocols_H__
#define __NGMimeGenerator_NGMimeGeneratorProtocols_H__

#import <Foundation/NSObject.h>
#import <NGMime/NGPart.h>

@class NSData, NGMutableHashMap;

@protocol NGMimePartGenerator <NSObject>

/* generate mime from part and store it in _file */
- (NSString *)generateMimeFromPartToFile:(id<NGMimePart>)_part;

- (NSData *)generateMimeFromPart:(id<NGMimePart>)_part;
- (void)setDelegate:(id)_delegate;
- (id)delegate;
- (void)setUseMimeData:(BOOL)_useMimeData;

@end

@protocol NGMimeBodyGenerator < NSObject >

- (NSData *)generateBodyOfPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders
  delegate:(id)_delegate;

- (NSData *)encodeData:(NSData *)_data
  forPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders;

/* use mime data objects to store mime objects on disk instead in memory */

- (void)setUseMimeData:(BOOL)_useMimeData;
@end

@protocol NGMimeHeaderFieldGenerator < NSObject >

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value;

@end

#endif // __NGMimeGenerator_NGMimeGeneratorProtocols_H__
