/*
  Copyright (C) 2005 Helge Hess

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

#include "NGVCardStrArrayValue.h"
#include "common.h"

@implementation NGVCardStrArrayValue

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithArray:(NSArray *)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  if ((self = [super initWithGroup:_group types:_types arguments:_a]) != nil) {
    self->values = [_plist copy];
  }
  return self;
}

- (id)initWithString:(NSString *)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  // TODO: unescaping of commas?
  return [self initWithArray:[_plist componentsSeparatedByString:@","]
	       group:_group types:_types arguments:_a];
}

- (id)initWithPropertyList:(id)_plist group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  if ([_plist isKindOfClass:[NSString class]]) {
    return [self initWithString:_plist
		 group:_group types:_types arguments:_a];
  }
  if ([_plist isKindOfClass:[NSArray class]]) {
    return [self initWithArray:_plist
		 group:_group types:_types arguments:_a];
  }

  [self logWithFormat:@"ERROR: unexpected property list type: %@",
	  [_plist class]];
  [self release];
  return nil;
}
- (id)initWithPropertyList:(id)_plist {
  return [self initWithPropertyList:_plist group:nil types:nil arguments:nil];
}

- (id)initWithGroup:(NSString *)_group types:(NSArray *)_types
  arguments:(NSDictionary *)_a
{
  return [self initWithArray:nil 
	       group:_group types:_types arguments:_a];
}
- (id)init {
  return [self initWithPropertyList:nil group:nil types:nil arguments:nil];
}

- (void)dealloc {
  [self->values release];
  [super dealloc];
}

/* accessors */

- (NSArray *)values {
  return self->values;
}

/* values */

- (NSString *)stringValue {
  return [self vCardString];
}

- (NSString *)xmlString {
  return [[self stringValue] stringByEscapingXMLString];
}

- (NSString *)vCardString {
  return [[self values] componentsJoinedByString:@","];
}

- (id)propertyList {
  return [self values];
}

- (NSArray *)asArray {
  return self->values;
}

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx {
  return [self->values objectAtIndex:_idx];
}
- (unsigned)count {
  return [self->values count];
}

/* fake being a string */

- (unichar)characterAtIndex:(unsigned)_idx {
  return [[self stringValue] characterAtIndex:_idx];
}
- (unsigned)length {
  return [[self stringValue] length];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  [_coder encodeObject:self->values];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder]) != nil) {
    self->values = [[_coder decodeObject] copy];
  }
  return self;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  [super appendAttributesToDescription:_ms];
  [_ms appendFormat:@" vcard=%@", [self vCardString]];
}

@end /* NGVCardStrArrayValue */
