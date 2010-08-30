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

#include "SaxAttributeList.h"
#include "SaxAttributes.h"
#include "common.h"

@implementation SaxAttributeList

- (id)init {
  self->names  = [[NSMutableArray alloc] init];
  self->types  = [[NSMutableArray alloc] init];
  self->values = [[NSMutableArray alloc] init];
  return self;
}
- (id)initWithAttributeList:(id<SaxAttributeList>)_attrList {
  if ((self = [self init])) {
    unsigned i;

    for (i = 0; i < [_attrList count]; i++) {
      [self->names  addObject:[_attrList nameAtIndex:i]];
      [self->types  addObject:[_attrList typeAtIndex:i]];
      [self->values addObject:[_attrList valueAtIndex:i]];
    }
  }
  return self;
}

- (id)initWithAttributes:(id<SaxAttributes>)_attrList {
  if ((self = [self init])) {
    int i, c;

    for (i = 0, c = [_attrList count]; i < c; i++) {
      [self->names  addObject:[_attrList rawNameAtIndex:i]];
      [self->types  addObject:[_attrList typeAtIndex:i]];
      [self->values addObject:[_attrList valueAtIndex:i]];
    }
  }
  return self;
}

- (void)dealloc {
  [self->names  release];
  [self->types  release];
  [self->values release];
  [super dealloc];
}

/* modify operations */

- (void)setAttributeList:(id<SaxAttributeList>)_attrList {
  unsigned i;

  [self clear];
  
  for (i = 0; i < [_attrList count]; i++) {
    [self->names  addObject:[_attrList nameAtIndex:i]];
    [self->types  addObject:[_attrList typeAtIndex:i]];
    [self->values addObject:[_attrList valueAtIndex:i]];
  }
}
- (void)clear {
  [self->names  removeAllObjects];
  [self->types  removeAllObjects];
  [self->values removeAllObjects];
}

- (void)addAttribute:(NSString *)_name
  type:(NSString *)_type
  value:(NSString *)_value
{
  if (_type  == nil) _type  = @"CDATA";
  if (_value == nil) _value = @"";
  [self->names  addObject:_name];
  [self->types  addObject:_type];
  [self->values addObject:_value];
}

- (void)removeAttribute:(NSString *)_name {
  int idx;

  if ((idx = [self->names indexOfObject:_name]) == NSNotFound)
    return;

  [self->names  removeObjectAtIndex:idx];
  [self->types  removeObjectAtIndex:idx];
  [self->values removeObjectAtIndex:idx];
}

/* protocol implementation */

- (NSString *)nameAtIndex:(NSUInteger)_idx {
  return [self->names objectAtIndex:_idx];
}
- (NSString *)typeAtIndex:(NSUInteger)_idx {
  return [self->types objectAtIndex:_idx];
}
- (NSString *)valueAtIndex:(NSUInteger)_idx {
  return [self->values objectAtIndex:_idx];
}

- (NSString *)typeForName:(NSString *)_name {
  int i;

  if ((i = [self->names indexOfObject:_name]) == NSNotFound)
    return nil;

  return [self typeAtIndex:i];
}
- (NSString *)valueForName:(NSString *)_name {
  int i;

  if ((i = [self->names indexOfObject:_name]) == NSNotFound)
    return nil;

  return [self valueAtIndex:i];
}

- (NSUInteger)count {
  return [self->names count];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[[self class] allocWithZone:_zone] initWithAttributeList:self];
}

/* description */

- (id)propertyList {
  id objs[3], keys[3];
  objs[0] = self->names;  keys[0] = @"names";
  objs[1] = self->types;  keys[1] = @"types";
  objs[2] = self->values; keys[2] = @"values";
  return [NSDictionary dictionaryWithObjects:objs forKeys:keys count:3];
}

- (NSString *)description {
  NSMutableString *s;
  NSString        *is;
  int i, c;
  
  s = [[NSMutableString alloc] init];
  [s appendFormat:@"<%08X[%@]:", self, NSStringFromClass([self class])];
  
  for (i = 0, c = [self count]; i < c; i++) {
    NSString *type;

    [s appendString:@" "];
    [s appendString:[self nameAtIndex:i]];
    [s appendString:@"='"];
    [s appendString:[self valueAtIndex:i]];
    [s appendString:@"'"];

    type = [self typeAtIndex:i];
    if (![type isEqualToString:@"CDATA"]) {
      [s appendString:@"["];
      [s appendString:type];
      [s appendString:@"]"];
    }
  }
  [s appendString:@">"];
  
  is = [s copy];
  [s release];
  return [is autorelease];
}

@end /* SaxAttributeList */
