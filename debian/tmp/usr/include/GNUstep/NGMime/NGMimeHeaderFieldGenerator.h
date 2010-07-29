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

#ifndef __NGMime_NGHeaderFieldGenerator_H__
#define __NGMime_NGHeaderFieldGenerator_H__

#import <Foundation/NSObject.h>
#include <NGMime/NGMimeGeneratorProtocols.h>

@class NSString, NSData, NSMutableDictionary;

@interface NGMimeHeaderFieldGenerator : NSObject <NGMimeHeaderFieldGenerator>

+ (id)headerFieldGenerator;

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value;

@end

@interface NGMimeContentTypeHeaderFieldGenerator : NGMimeHeaderFieldGenerator
@end

@interface NGMimeContentLengthHeaderFieldGenerator : NGMimeHeaderFieldGenerator
@end

@interface NGMimeRFC822DateHeaderFieldGenerator : NGMimeHeaderFieldGenerator
@end

@interface NGMimeContentDispositionHeaderFieldGenerator :
                                                     NGMimeHeaderFieldGenerator
@end

@interface NGMimeStringHeaderFieldGenerator : NGMimeHeaderFieldGenerator
@end

@interface NGMimeAddressHeaderFieldGenerator : NGMimeHeaderFieldGenerator
@end

@interface NGMimeHeaderFieldGeneratorSet : NSObject <NGMimeHeaderFieldGenerator>
{
@protected
  NSMutableDictionary            *fieldNameToGenerate;
  id<NGMimeHeaderFieldGenerator> defaultGenerator;
}

+ (id)headerFieldGeneratorSet;
+ (id)defaultRfc822HeaderFieldGeneratorSet;

- (id)init;
- (id)initWithDefaultGenerator:(id<NGMimeHeaderFieldGenerator>)_gen;

/* accessors */

- (void)setGenerator:(id<NGMimeHeaderFieldGenerator>)_gen
  forField:(NSString *)_name;

- (void)setDefaultGenerator:(id<NGMimeHeaderFieldGenerator>)_gen;
- (id<NGMimeHeaderFieldGenerator>)_gen;

/* operation */

- (NSData *)generateDataForHeaderFieldNamed:(NSString *)_headerField
  value:(id)_value;

@end

extern int NGEncodeQuotedPrintableMime
(const unsigned char *_src, unsigned _srcLen,
 unsigned char *_dest, unsigned _destLen);

#endif // __NGMime_NGHeaderFieldGenerator_H__
