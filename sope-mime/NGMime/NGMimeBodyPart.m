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

#include "NGMimeBodyPart.h"
#include "NGMimeType.h"
#include "common.h"
#include "NGMimeFileData.h"
#include <NGMime/NGMimePartParser.h>

@implementation NGMimeBodyPart

+ (int)version {
  return 2;
}

+ (id)bodyPartWithHeader:(NGHashMap *)_header {
  return [[[self alloc] initWithHeader:_header] autorelease];
}

- (id)initWithHeader:(NGHashMap *)_header {
  if ((self = [super init])) {
    self->header = [_header retain];
    self->body   = nil;
  }
  return self;
}
- (id)init {
  return [self initWithHeader:nil];
}

- (void)dealloc {
  [self->header release];
  [self->body   release];
  [super dealloc];
}

/* NGPart */

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name {
  return [self->header objectEnumeratorForKey:_name];
}
- (NSEnumerator *)headerFieldNames {
  return [self->header keyEnumerator];
}

- (void)setBody:(id)_body {
  ASSIGN(self->body, _body);
}
- (id)body {
  return self->body;
}

/* convenience */

- (NSString *)headerForKey:(NSString *)_key {
  return [[self->header objectEnumeratorForKey:_key] nextObject];
}

- (NSArray *)headersForKey:(NSString *)_key {
  NSEnumerator   *values;
  NSMutableArray *array;
  id value;
  
  if ((values = [self->header objectEnumeratorForKey:_key]) == nil)
    return nil;
  
  array = [NSMutableArray arrayWithCapacity:4];
  while ((value = [values nextObject]) != nil)
    [array addObject:value];
  return array;
}

- (NSArray *)headerKeys {
  NSEnumerator *values;
  NSMutableArray *array  = nil;
  id name = nil;

  if ((values = [self->header keyEnumerator]) == nil)
    return nil;
  
  array = [[NSMutableArray alloc] init];
  while ((name = [values nextObject]) != nil)
    [array addObject:name];

  name = [array copy];
  [array release];
  
  return [name autorelease];
}

- (NSDictionary *)headers {
  return [self->header asDictionary];
}

- (NSString *)headersAsString {
  // TODO: not correct for MIME
  NSMutableString *ms;
  NSEnumerator *keys;
  NSString     *key;
  
  ms = [NSMutableString stringWithCapacity:1024];
  
  /* headers */
  keys = [[self headerKeys] objectEnumerator];
  while ((key = [keys nextObject]) != nil) {
    NSEnumerator *vals;
    id val;
    
    vals = [[self headersForKey:key] objectEnumerator];
    while ((val = [vals nextObject])) {
      [ms appendString:key];
      [ms appendString:@": "];
      [ms appendString:[val stringValue]];
      [ms appendString:@"\r\n"];
    }
  }
  return ms;
}

/* NGMimePart */

- (NGMimeType *)contentType {
  id type;
  static NGMimeHeaderNames *Fields = NULL;

  if (!Fields)
    Fields = (NGMimeHeaderNames *)[NGMimePartParser headerFieldNames];
  
  type = [self->header objectForKey:Fields->contentType];
  
  if (![type isKindOfClass:[NGMimeType class]])
    type = [NGMimeType mimeType:[type stringValue]];
  
  return type;
}

- (NSString *)contentId {
  return [[self->header objectForKey:@"content-id"] stringValue];
}

- (NSArray *)contentLanguage {
  id value;
  
  value = [self->header objectForKey:@"content-language"];
  if (![value isKindOfClass:[NSArray class]])
    value = [value componentsSeparatedByString:@","];

  return value;
}

- (NSString *)contentMd5 {
  return [[self->header objectForKey:@"content-md5"] stringValue];
}

- (NSString *)encoding {
  return [[self->header objectForKey:@"content-transfer-encoding"]
                        stringValue];
}

- (NSString *)contentDescription {
  return [[self->header objectForKey:@"content-description"] stringValue];
}

/* description */

- (NSString *)description {
  NSMutableString *d;
  id b = [self body];

  d = [NSMutableString stringWithCapacity:128];

  [d appendFormat:@"<%@[0x%p]: header=%@",
       NSStringFromClass([self class]), self, self->header];

  if (b) [d appendFormat:@" bodyClass=%@", NSStringFromClass([b class])];

  if ([b isKindOfClass:[NGMimeFileData class]]) {
    [d appendFormat:@" body=%@", b];
  }
  else if ([b isKindOfClass:[NSString class]] ||
           [b isKindOfClass:[NSData class]]) {
    if ([b length] < 512) {
      [d appendFormat:@" bodyLen=%i body=%@", [b length], b];
    }
    else
      [d appendFormat:@" body[len=%i]", [b length]];
  }
  else
    [d appendFormat:@" body=%@", b];
  
  [d appendString:@">"];
  return d;
}

@end /* NGMimeBodyPart */
