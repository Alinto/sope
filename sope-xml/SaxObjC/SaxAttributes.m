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

#include "SaxAttributes.h"
#include "common.h"

@implementation SaxAttributes

- (id)init {
  Class c = [NSMutableArray class];
  
  self->names    = [[c alloc] init];
  self->uris     = [[c alloc] init];
  self->rawNames = [[c alloc] init];
  self->types    = [[c alloc] init];
  self->values   = [[c alloc] init];
  return self;
}
- (id)initWithAttributes:(id<SaxAttributes>)_attrs {
  if ((self = [self init])) {
    int i, c;
    
    for (i = 0, c = [_attrs count]; i < c; i++) {
      [self addAttribute:[_attrs nameAtIndex:i]
            uri:[_attrs uriAtIndex:i]
            rawName:[_attrs rawNameAtIndex:i]
            type:[_attrs typeAtIndex:i]
            value:[_attrs valueAtIndex:i]];
    }
  }
  return self;
}

- (id)initWithAttributeList:(id<SaxAttributeList>)_attrList {
  if ((self = [self init])) {
    unsigned i;
    
    for (i = 0; i < [_attrList count]; i++) {
      [self addAttribute:[_attrList nameAtIndex:i] uri:@""
            rawName:[_attrList nameAtIndex:i]
            type:[_attrList typeAtIndex:i]
            value:[_attrList valueAtIndex:i]];
    }
  }
  return self;
}
- (id)initWithDictionary:(NSDictionary *)_dict {
  if ((self = [self init])) {
    NSEnumerator *keys;
    NSString     *key;
    
    keys = [_dict keyEnumerator];
    while ((key = [keys nextObject])) {
      [self addAttribute:key uri:nil rawName:key
            type:nil 
            value:[_dict objectForKey:key]];
    }
  }
  return self;
}

- (void)dealloc {
  [self->names    release];
  [self->uris     release];
  [self->rawNames release];
  [self->types    release];
  [self->values   release];
  [super dealloc];
}

/* modifications */

- (void)addAttribute:(NSString *)_localName uri:(NSString  *)_uri
  rawName:(NSString *)_rawName
  type:(NSString *)_type
  value:(NSString *)_value
{
  [self->names    addObject:_localName ? _localName : _rawName];
  [self->uris     addObject:_uri       ? _uri       : (NSString *)@""];
  [self->rawNames addObject:_rawName   ? _rawName   : (NSString *)@""];
  [self->types    addObject:_type      ? _type      : (NSString *)@"CDATA"];
  [self->values   addObject:_value];
}

- (void)clear {
  [self->names    removeAllObjects];
  [self->uris     removeAllObjects];
  [self->rawNames removeAllObjects];
  [self->types    removeAllObjects];
  [self->values   removeAllObjects];
}

/* lookup indices */

- (NSUInteger)indexOfRawName:(NSString *)_rawName {
  return [self->rawNames indexOfObject:_rawName];
}
- (NSUInteger)indexOfName:(NSString *)_localPart uri:(NSString *)_uri
{
  unsigned int i, c;
  
  for (i = 0, c = [self count]; i < c; i++) {
    NSString *name;
    
    name = [self nameAtIndex:i];
    
    if ([name isEqualToString:_localPart]) {
      NSString *auri;
      
      auri = [self uriAtIndex:i];

      //NSLog(@"found name %@", name);
      
      if (([auri length] == 0) && ([_uri length] == 0))
        return i;
      
      if ([_uri isEqualToString:auri])
        return i;
    }
  }
  return NSNotFound;
}

/* lookup data by index */

- (NSString *)nameAtIndex:(NSUInteger)_idx {
  return [self->names objectAtIndex:_idx];
}
- (NSString *)rawNameAtIndex:(NSUInteger)_idx {
  return [self->rawNames objectAtIndex:_idx];
}
- (NSString *)typeAtIndex:(NSUInteger)_idx {
  return [self->types objectAtIndex:_idx];
}
- (NSString *)uriAtIndex:(NSUInteger)_idx {
  return [self->uris objectAtIndex:_idx];
}
- (NSString *)valueAtIndex:(NSUInteger)_idx {
  return [self->values objectAtIndex:_idx];
}

/* lookup data by name */

- (NSString *)typeForRawName:(NSString *)_rawName {
  unsigned int i;

  if ((i = [self indexOfRawName:_rawName]) == NSNotFound)
    return nil;

  return [self typeAtIndex:i];
}
- (NSString *)typeForName:(NSString *)_localName uri:(NSString *)_uri {
  unsigned int i;
  
  if ((i = [self indexOfName:_localName uri:_uri]) == NSNotFound)
    return nil;

  return [self typeAtIndex:i];
}

- (NSString *)valueForRawName:(NSString *)_rawName {
  unsigned int i;

  if ((i = [self indexOfRawName:_rawName]) == NSNotFound)
    return nil;

  return [self valueAtIndex:i];
}
- (NSString *)valueForName:(NSString *)_localName uri:(NSString *)_uri {
  unsigned int i;
  
  if ((i = [self indexOfName:_localName uri:_uri]) == NSNotFound)
    return nil;

  return [self valueAtIndex:i];
}

/* list size */

- (NSUInteger)count {
  return [self->names count];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [(SaxAttributes *)[[self class] alloc] initWithAttributes:self];
}

/* description */

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

@end /* SaxAttributes */
