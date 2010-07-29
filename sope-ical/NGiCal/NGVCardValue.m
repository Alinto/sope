/*
  Copyright (C) 2005-2007 Helge Hess

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

#include "NGVCardValue.h"
#include <NGExtensions/NSString+misc.h>
#include "common.h"

@implementation NGVCardValue

+ (int)version {
  return [super version] + 0 /* v0 */;
}

- (id)initWithGroup:(NSString *)_group types:(NSArray *)_types
  arguments:(NSDictionary *)_a
{
  if ((self = [super init]) != nil) {
    self->group     = [_group copy];
    self->types     = [_types copy];
    self->arguments = [_a copy];
  }
  return self;
}
- (id)init {
  return [self initWithGroup:nil types:nil arguments:nil];
}

- (void)dealloc {
  [self->group     release];
  [self->types     release];
  [self->arguments release];
  [super dealloc];
}

/* accessors */

- (NSString *)group {
  return self->group;
}
- (NSArray *)types {
  return self->types;
}
- (NSDictionary *)arguments {
  return self->arguments;
}
- (BOOL)isPreferred {
  return [self->types containsObject:@"PREF"];
}

/* values */

- (NSString *)stringValue {
  [self logWithFormat:@"ERROR(%s): subclasses should override this method!",
	__PRETTY_FUNCTION__];
  return nil;
}

- (id)propertyList {
  return [self stringValue];
}

- (NSString *)xmlString {
  return [[self stringValue] stringByEscapingXMLString];
}

- (NSString *)vCardString {
  // TODO: apply proper escaping
  return [self stringValue];
}

/* misc support methods */

- (void)appendXMLTag:(NSString *)_tag value:(NSString *)_val
  to:(NSMutableString *)_ms
{
  [_ms appendString:@"<"];
  [_ms appendString:_tag];
  [_ms appendString:@">"];
  if ([_val isNotNull]) [_ms appendString:[_val stringByEscapingXMLString]];
  [_ms appendString:@"</"];
  [_ms appendString:_tag];
  [_ms appendString:@">"];
}

- (void)appendVCardValue:(NSString *)_val to:(NSMutableString *)_ms {
  // TODO: properly escape!
  if ([_val isNotNull]) [_ms appendString:_val];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* values are considered immutable */
  return [self retain];
}

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
- (id)valueForUndefinedKey:(NSString *)_key {
  [self warnWithFormat:@"attempted to retrieve undefined key %@: %@", 
	  _key, self];
  return nil;
}
#endif


/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->group];
  [_coder encodeObject:self->types];
  [_coder encodeObject:self->arguments];
}
- (id)initWithCoder:(NSCoder *)_coder {
  self->group     = [[_coder decodeObject] copy];
  self->types     = [[_coder decodeObject] copy];
  self->arguments = [[_coder decodeObject] copy];
  return self;
}

/* description */

- (void)appendDictionary:(NSDictionary *)_d compactTo:(NSMutableString *)_s {
  NSEnumerator *keys;
  NSString *k;
  
  keys = [_d keyEnumerator];
  while ((k = [keys nextObject]) != nil) {
    NSString *v;
    
    v = [_d objectForKey:k];
    [_s appendFormat:@"%@='%@';", k, v];
  }
}

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  if (self->group != nil) [_ms appendFormat:@" group='%@'", self->group];
  if ([self->types count] > 0) {
    [_ms appendFormat:@" types=%@", 
	   [self->types componentsJoinedByString:@","]];
  }
  if ([self->arguments count] > 0) {
    [_ms appendString:@" args="];
    [self appendDictionary:self->arguments compactTo:_ms];
  }
}

- (NSString *)description {
  NSMutableString *str = nil;
  
  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:str];
  [str appendString:@">"];
  return str;
}

@end /* NGVCardValue */
