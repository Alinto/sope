/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "EOKeyGlobalID.h"
#include "common.h"

@implementation EOKeyGlobalID

+ (id)globalIDWithEntityName:(NSString *)_name
  keys:(id *)_keyValues
  keyCount:(unsigned int)_count
  zone:(NSZone *)_zone
{
  EOKeyGlobalID *kid;

  NSAssert1(_count > 0, 
	    @"missing key-values (count is 0, entity is %@", _name);
  
  if ((kid = (id)NSAllocateObject(self, sizeof(id) * _count, _zone))) {
    unsigned int i;
    kid->entityName = [_name copyWithZone:_zone];
    kid->count      = _count;
    
    for (i = 0; i < _count; i++) {
#if DEBUG
      if (_keyValues[i] == nil) {
	NSLog(@"WARN(%s): got 'nil' as a EOKeyGlobalID value (entity=%@)!",
	      __PRETTY_FUNCTION__, _name);
      }
#endif
      kid->values[i] = [_keyValues[i] retain];
    }

    return [kid autorelease];
  }
  
  return nil;
}

- (void)dealloc {
  unsigned int i;
  for (i = 0; i < self->count; i++) {
    [self->values[i] release];
    self->values[i] = nil;
  }
  [self->entityName release];
  [super dealloc];
}

/* accessors */

- (NSString *)entityName {
  return self->entityName;
}

- (unsigned int)keyCount {
  return self->count;
}
- (id *)keyValues {
  return &(self->values[0]);
}

- (NSArray *)keyValuesArray {
  return [NSArray arrayWithObjects:&(self->values[0]) count:self->count];
}

/* Equality */

- (NSUInteger)hash {
  return [self->entityName hash] - [self->values[0] hash];
}

- (BOOL)isEqual:(id)_other {
  EOKeyGlobalID *otherKey;
  unsigned int i;

  if (_other == nil)  return NO;
  if (_other == self) return YES;
  otherKey = _other;
  if (otherKey->isa   != self->isa)   return NO;
  if (otherKey->count != self->count) return NO;
  if (![otherKey->entityName isEqualToString:self->entityName]) return NO;
  
  for (i = 0; i < self->count; i++) {
    if (self->values[i] != otherKey->values[i]) {
      if (![self->values[i] isEqual:otherKey->values[i]])
        return NO;
    }
  }
  
  return YES;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [self doesNotRecognizeSelector:_cmd];
}
- (id)initWithCoder:(NSCoder *)_coder {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
#if 0
  NSString     *entityName;
  NSZone       *z;
  unsigned int count;
  
  z = [self zone];
  [self release];

  entityName = [_coder decodeObject];
  
  self = [EOKeyGlobalID globalIDWithEntityName:entityName
                        keys:NULL
                        keyCount:0
                        zone:z];
  return [self retain];
#endif
}

/* description */

- (NSString *)description {
  NSMutableString *s;
  NSString *d;
  unsigned int i;
  
  s = [[NSMutableString alloc] init];
  [s appendFormat:@"<0x%p[%@]: %@",
       self, NSStringFromClass([self class]),
       [self entityName]];

  if (self->count == 0) {
    [s appendString:@" no-key-values"];
  }
  else {
    for (i = 0; i < self->count; i++) {
      if (i == 0) [s appendString:@" "];
      else        [s appendString:@"/"];
      if (self->values[i] == nil)
	[s appendString:@"<nil>"];
      else if (self->values[i] == nil)
	[s appendString:@"<NSNull>"];
      else
	[s appendString:[self->values[i] stringValue]];
    }
  }
  
  [s appendString:@">"];

  d = [s copy];
  [s release];
  return [d autorelease];
}

@end /* EOKeyGlobalID */
