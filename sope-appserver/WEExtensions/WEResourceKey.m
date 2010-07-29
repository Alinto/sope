/*
  Copyright (C) 2004-2005 Helge Hess

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

#include "WEResourceKey.h"
#include "common.h"

@implementation WEResourceKey

- (id)initCachedKey {
  if ((self = [self init])) {
    self->flags.retainsValues = 0;
  }
  return self;
}

- (void)dealloc {
  if (self->flags.retainsValues) {
    [self->frameworkName release];
    [self->name          release];
    [self->language      release];
  }
  [super dealloc];
}

/* NSCopying */

- (id)duplicate {
  /* returns a retained object */
  WEResourceKey *newKey;
  
  newKey = [[[self class] alloc] init];
  newKey->flags.retainsValues = 1;
  newKey->hashValue     = self->hashValue;
  newKey->frameworkName = [self->frameworkName copy];
  newKey->name          = [self->name          copy];
  newKey->language      = [self->language      copy];
  return newKey;
}

- (id)copyWithZone:(NSZone *)_zone {
  if (!self->flags.retainsValues)
    return [self duplicate];
  
  /* we are immutable */
  return [self retain];
}

/* equality */

- (unsigned)hash {
  if (self->hashValue == 0) {
    /* don't know whether this is smart, Nat! needs to comment ;-) */
    self->hashValue = [self->name hash];
    if (self->language != nil)
      self->hashValue += [self->language characterAtIndex:0];
  }
  return self->hashValue;
}

- (BOOL)isEqual:(id)_other {
  /* this method isn't very tolerant, but fast ;-) */
  WEResourceKey *okey;
  
  if (_other == nil)  return NO;
  if (_other == self) return YES;
  if (*(Class*)_other != *(Class *)self) return NO;
  okey = _other;
  
  if (self->name != okey->name) {
    if (![self->name isEqualToString:okey->name])
      return NO;
  }
  if (self->language != okey->language) {
    if (![self->language isEqualToString:okey->language])
      return NO;
  }
  if (self->frameworkName != okey->frameworkName) {
    if (![self->frameworkName isEqualToString:okey->frameworkName])
      return NO;
  }
  return YES;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  if (self->name)          [ms appendFormat:@" name=%@", self->name];
  if (self->frameworkName) [ms appendFormat:@" fw=%@",   self->frameworkName];
  if (self->language)      [ms appendFormat:@" lang=%@", self->language];
  [ms appendString:@">"];
  return ms;
}

@end /* WEResourceKey */
