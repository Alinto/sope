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

#include "NGMimeMultipartBody.h"
#include "NGMimeBodyParser.h"
#include "common.h"

@implementation NGMimeMultipartBody

+ (int)version {
  return 2;
}

- (id)initWithPart:(id<NGMimePart>)_part {
  if ((self = [super init])) {
    self->flags.isParsed = YES;
  }
  return self;
}
- (id)initWithPart:(id<NGMimePart>)_part data:(NSData *)_data 
  delegate:(id)_del 
{
  if ((self = [self initWithPart:_part])) {
    self->flags.isParsed = NO;
    self->rawData        = [_data retain];
    self->delegate       = _del;
  }
  return self;
}
- (id)init {
  return [self initWithPart:nil];
}

- (void)dealloc {
  [self->rawData   release];
  [self->prefix    release];
  [self->suffix    release];
  [self->bodyParts release];
  [super dealloc];
}

/* parsing */

- (void)parse {
  NGMimeMultipartBodyParser *parser = [[NGMimeMultipartBodyParser alloc] init];

  self->flags.isParsed = YES;
  
  if (![parser parseBody:  self
               ofMultipart:self->part
               data:       self->rawData
               delegate:   self->delegate])
    NSLog(@"%@: error during parsing of multipart body (ignored)", self);

  self->delegate = nil;

  [parser release]; parser = nil;
}

static inline void _checkParse(NGMimeMultipartBody *self) {
  if (!self->flags.isParsed) [self parse];
}
static inline void _checkArray(NGMimeMultipartBody *self) {
  if (!self->flags.isParsed) [self parse];
  if (self->bodyParts == nil)
    self->bodyParts = [[NSMutableArray alloc] init];
}

/* accessors */

- (id<NGMimePart>)part { // the part the body belongs to
  return self->part;
}

- (NSArray *)parts {
  return self->bodyParts;
}

- (void)addBodyPart:(id<NGPart>)_part {
  _checkArray(self);
  [self->bodyParts addObject:_part];
}
- (void)addBodyPart:(id<NGPart>)_part atIndex:(int)_idx {
  _checkArray(self);
  [self->bodyParts insertObject:_part atIndex:_idx];
}

- (void)removeBodyPart:(id<NGPart>)_part {
  _checkArray(self);
  [self->bodyParts removeObject:_part];
}
- (void)removeBodyPartAtIndex:(int)_idx {
  _checkArray(self);
  [self->bodyParts removeObjectAtIndex:_idx];
}

- (void)setPrefix:(NSString *)_prefix {
  if (self->prefix != _prefix) {
    [self->prefix release];
    self->prefix = [_prefix copy];
  }
}
- (NSString *)prefix {
  return self->prefix;
}

- (void)setSuffix:(NSString *)_suffix {
  if (self->suffix != _suffix) {
    [self->suffix release];
    self->suffix = [_suffix copy];
  }
}
- (NSString *)suffix {
  return self->suffix;
}

/* description */

- (NSString *)description {
  NSMutableString *d = [NSMutableString stringWithCapacity:64];

  [d appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  
  if (self->flags.isParsed) {
    if (self->prefix)    [d appendFormat:@" prefix=%@", self->prefix];
    if (self->suffix)    [d appendFormat:@" suffix=%@", self->suffix];
    if (self->bodyParts) [d appendFormat:@" parts=%@",  self->bodyParts];
  }
  if (self->rawData) [d appendFormat:@" data=%@", self->rawData];
  
  [d appendString:@">"];
  return d;
}

@end /* NGMimeMultipartBody */
