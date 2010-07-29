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

#include "NGVCardOrg.h"
#include "common.h"

@implementation NGVCardOrg

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithName:(NSString *)_name units:(NSArray *)_units
  group:(NSString *)_grp types:(NSArray *)_tps arguments:(NSDictionary *)_a
{
  if ((self = [super initWithGroup:_grp types:_tps arguments:_a]) != nil) {
    self->orgnam   = [_name  copy];
    self->orgunits = [_units copy];
  }
  return self;
}

- (id)initWithGroup:(NSString *)_group types:(NSArray *)_types
  arguments:(NSDictionary *)_a
{
  return [self initWithName:nil units:nil
	       group:_group types:_types arguments:_a];
}
- (id)init {
  return [self initWithName:nil units:nil group:nil types:nil arguments:nil];
}

- (void)dealloc {
  [self->orgnam   release];
  [self->orgunits release];
  [super dealloc];
}

/* accessors */

- (NSString *)orgnam {
  return self->orgnam;
}
- (NSArray *)orgunits {
  return self->orgunits;
}

- (NSString *)orgunit {
  return [self->orgunits count] > 0 ? [self->orgunits objectAtIndex:0] : nil;
}

/* fake being an array */

- (id)objectAtIndex:(unsigned)_idx {
  NSString *s;

  if (_idx == 0)
    return (s = [self orgnam]) ? s : (NSString *)[NSNull null];
  
  return [self->orgunits objectAtIndex:(_idx - 1)];
}
- (unsigned)count {
  return 1 + [self->orgunits count];
}

/* values */

- (NSString *)stringValue {
  return [self vCardString];
}

- (NSString *)xmlString {
  NSMutableString *ms;
  NSString *s;
  unsigned i;
  
  ms = [[NSMutableString alloc] initWithCapacity:256];
  [self appendXMLTag:@"orgnam" value:[self orgnam] to:ms];
  
  for (i = 0; i < [self->orgunits count]; i++) {
    [self appendXMLTag:@"orgunit" value:[self->orgunits objectAtIndex:i]
	  to:ms];
  }
  s = [[ms copy] autorelease];
  [ms release];
  return s;
}

- (NSString *)vCardString {
  NSMutableString *ms;
  NSString *s;
  unsigned i;
  
  ms = [[NSMutableString alloc] initWithCapacity:64];
  [self appendVCardValue:[self orgnam] to:ms];
  for (i = 0; i < [self->orgunits count]; i++) {
    [ms appendString:@";"];
    [self appendVCardValue:[self->orgunits objectAtIndex:i] to:ms];
  }
  s = [[ms copy] autorelease];
  [ms release];
  return s;
}

- (NSDictionary *)asDictionary {
  static NSString *keys[2] = { @"orgnam", @"orgunits" };
  id values[2];
  
  values[0] = [self orgnam];
  values[1] = [self orgunits];
  
  return [NSDictionary dictionaryWithObjects:values forKeys:keys 
		       count:[self count]];
}

- (NSArray *)asArray {
  id values[[self count] + 1];
  unsigned i;

  for (i = 0; i < [self count]; i++)
    values[i] = [self objectAtIndex:i];
  
  return [NSArray arrayWithObjects:values count:[self count]];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  
  [_coder encodeObject:self->orgnam];
  [_coder encodeObject:self->orgunits];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder]) != nil) {
    self->orgnam   = [[_coder decodeObject] copy];
    self->orgunits = [[_coder decodeObject] copy];
  }
  return self;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  if (self->orgnam) [_ms appendFormat:@" %@", self->orgnam];
  if ([self->orgunits count] > 0) {
    [_ms appendFormat:@" units=%@",
	 [self->orgunits componentsJoinedByString:@","]];
  }
  [super appendAttributesToDescription:_ms];
}

@end /* NGVCardOrg */
