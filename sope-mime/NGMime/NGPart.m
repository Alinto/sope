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

#include "NGPart.h"
#include "NGMimeType.h"
#include "common.h"
#include <NGMime/NGMimePartParser.h>

@implementation NSData(DataPart)

/* NGPart */

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name {
  id value = nil;

  static NGMimeHeaderNames *Fields = NULL;

  if (!Fields)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
  
  if ([_name isEqualToString:Fields->contentLength])
    value = [NSNumber numberWithUnsignedInt:[self length]];
  else if ([_name isEqualToString:Fields->contentType])
    value = [self contentType];
  else if ([_name isEqualToString:@"content-id"])
    value = [self contentId];
  else if ([_name isEqualToString:@"content-m5"])
    value = [self contentMd5];
  else if ([_name isEqualToString:@"content-language"])
    value = [self contentLanguage];

  if (value)
    return [[NSArray arrayWithObject:value] objectEnumerator];
  
  return nil;
}
- (NSEnumerator *)headerFieldNames {
  return nil;
}

- (void)setBody:(id)_body {
  [self doesNotRecognizeSelector:_cmd];
}
- (id)body {
  return self;
}

/* NGMimePart */

- (NGMimeType *)contentType {
  static NGMimeType *defType = nil;
  if (defType == nil)
    defType = [[NGMimeType mimeType:@"application/octet-stream"] retain];
  return defType;
}
- (NSString *)contentId {
  return nil;
}

- (NSArray *)contentLanguage {
  return nil;
}
- (NSString *)contentMd5 {
  return nil;
}
- (NSString *)encoding {
  return nil;
}

@end /* NSData(DataPart) */

@implementation NSMutableData(DataPart)

- (void)setBody:(id)_body {
  [self setData:_body];
}

@end /* NSMutableData(DataPart) */

void __link_NGPart(void) {
  __link_NGPart();
}
