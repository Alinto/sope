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

#ifndef __NGMime_NGMimeMultipartBody_H__
#define __NGMime_NGMimeMultipartBody_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGPart.h>

@class NSData, NSString, NSMutableArray;

/*
  Represents bodies of multipart entities.
  Multipart bodies can be parsed 'on-demand'.

  ATTENTION: the delegate is _required_ to persist until the multipart body
             is parsed ! The body does not retain the delegate.
*/

@interface NGMimeMultipartBody : NSObject
{
@protected
  id<NGMimePart> part;     /* non-retained */
  NSString       *prefix;
  NSString       *suffix;
  NSMutableArray *bodyParts;

  // for on-demand parsing
  NSData         *rawData;
  id             delegate; /* non-retained */
  
  struct {
    BOOL isParsed:1;
  } flags;
}

- (id)initWithPart:(id<NGMimePart>)_part; // designated initializer
- (id)initWithPart:(id<NGMimePart>)_part
  data:(NSData *)_data
  delegate:(id)_delegate;

// accessors

- (id<NGMimePart>)part; // the part the body belongs to

- (NSArray *)parts;
- (void)addBodyPart:(id<NGPart>)_part;
- (void)addBodyPart:(id<NGPart>)_part atIndex:(int)_idx;
- (void)removeBodyPart:(id<NGPart>)_part;
- (void)removeBodyPartAtIndex:(int)_idx;

- (void)setPrefix:(NSString *)_prefix;
- (NSString *)prefix;
- (void)setSuffix:(NSString *)_suffix;
- (NSString *)suffix;

@end

#endif /* __NGMime_NGMimeMultipartBody_H__ */
