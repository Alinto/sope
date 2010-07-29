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

#include "NGVCardSimpleValue.h"
#include "common.h"

@implementation NGVCardSimpleValue

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithValue:(NSString *)_value group:(NSString *)_group 
  types:(NSArray *)_types arguments:(NSDictionary *)_a
{
  if ((self = [super initWithGroup:_group types:_types arguments:_a]) != nil) {
    self->value = [_value copy];
  }
  return self;
}

- (id)initWithGroup:(NSString *)_group types:(NSArray *)_types
  arguments:(NSDictionary *)_a
{
  return [self initWithValue:nil group:_group types:_types arguments:_a];
}
- (id)init {
  return [self initWithValue:nil group:nil types:nil arguments:nil];
}

- (void)dealloc {
  [self->value release];
  [super dealloc];
}

/* values */

- (NSString *)stringValue {
  return self->value;
}

- (id)propertyList {
  return [self stringValue];
}

/* fake being a string */

- (unichar)characterAtIndex:(unsigned)_idx {
  return [self->value characterAtIndex:_idx];
}
- (unsigned)length {
  return [self->value length];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  [_coder encodeObject:self->value];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder]) != nil) {
    self->value = [[_coder decodeObject] copy];
  }
  return self;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  if (self->value != nil) [_ms appendFormat:@" value='%@'", self->value];
  [super appendAttributesToDescription:_ms];
}

@end /* NGVCardSimpleValue */
