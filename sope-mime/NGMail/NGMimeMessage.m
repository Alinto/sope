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

#include "NGMimeMessage.h"
#include "common.h"

@implementation NGMimeMessage

static NGMimeType *defaultTextType = nil;
static NGMimeType *defaultDataType = nil;

+ (int)version {
  return 2;
}

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;
    
    defaultTextType = 
      [[NGMimeType mimeType:@"text/plain; charset=us-ascii"] retain];
    defaultDataType = 
      [[NGMimeType mimeType:@"application/octet-stream"] retain];
  }
}
  
+ (id)messageWithHeader:(NGHashMap *)_header {
  return [[[self alloc] initWithHeader:_header] autorelease];
}

- (id)init {
  return [self initWithHeader:nil];
}
- (id)initWithHeader:(NGHashMap *)_header {
  if ((self = [super init])) {
    self->header = [_header retain];
  }
  return self;
}

- (void)dealloc {
  [self->header   release];
  [self->body     release];
  [self->mimeType release];
  [super dealloc];
}

/* NGPart */

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name {
  if ([_name isEqualToString:@"content-type"])
    return [[NSArray arrayWithObject:[self contentType]] objectEnumerator];
  
  return [self->header objectEnumeratorForKey:_name];
}
- (NSEnumerator *)headerFieldNames {
  return [self->header keyEnumerator];
}

- (void)setBody:(id)_body {
  ASSIGN(self->body,     _body);
  ASSIGN(self->mimeType, (id)nil);
}
- (id)body {
  return self->body;
}

/* NGMimePart */

- (NGMimeType *)autodetectContentType {
  const char *bytes;
  unsigned   length;
  
  if (!((self->body != nil) && [self->body isKindOfClass:[NSData class]]))
    return defaultTextType;
  
  bytes  = [self->body bytes];
  length = [self->body length];
  while (length > 0) {
    if ((unsigned char)*bytes > 127)
      break;
    
    bytes++;
    length--;
  }
  return (length > 0) ? defaultDataType : defaultTextType;
}

- (NGMimeType *)contentType {
  if (self->mimeType == nil) {
    NGMimeType *type = nil;
    
    if ((type = [self->header objectForKey:@"content-type"]) == nil)
      type = [self autodetectContentType];
    
    if (![type isKindOfClass:[NGMimeType class]])
      type = [NGMimeType mimeType:[type stringValue]];
    
    ASSIGNCOPY(self->mimeType, type);
  }
  return self->mimeType;
}

- (NSString *)contentId {
  return [[self->header objectForKey:@"content-id"] stringValue];
}

- (NSArray *)contentLanguage {
  return [self->header objectForKey:@"content-language"];
}

- (NSString *)contentMd5 {
  return [[self->header objectForKey:@"content-md5"] stringValue];
}

- (NSString *)encoding {
  return [[self->header objectForKey:@"content-transfer-encoding"] stringValue];
}

- (NSString *)contentDescription {
  return [self->header objectForKey:@"content-description"];
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

/* description */

- (NSString *)description {
  NSMutableString *d;
  id b;

  d = [NSMutableString stringWithCapacity:64];
  [d appendFormat:@"<%@[0x%p]: header=%@",
       NSStringFromClass([self class]), self, self->header];

  b = [self body];
  if ([b isKindOfClass:[NSString class]] || [b isKindOfClass:[NSData class]]) {
    if ([b length] < 512)
      [d appendFormat:@" body=%@", b];
    else
      [d appendFormat:@" body[len=%i]", [b length]];
  }
  else
    [d appendFormat:@" body=%@", b];
  
  [d appendString:@">"];
  return d;
}

@end /* NGMimeMessage */
