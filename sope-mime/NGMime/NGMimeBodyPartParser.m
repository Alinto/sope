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

#include "NGMimeBodyPartParser.h"
#include "NGMimeBodyPart.h"
#include "common.h"

@implementation NGMimeBodyPartParser

+ (int)version {
  return 3;
}
+ (void)initialize {
  NSAssert2([super version] == 3,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (NGMimeType *)defaultContentTypeForPart:(id<NGMimePart>)_part {
  return [NGMimeType mimeType:@"text/plain"];
}

- (id<NGMimePart>)producePartWithHeader:(NGHashMap *)_header {
  return [NGMimeBodyPart bodyPartWithHeader:_header];
}

- (void)parseBodyOfPart:(id<NGMimePart>)_part {
  [super parseBodyOfPart:_part];
}

@end /* NGMimeBodyPartParser */
