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

#include "SoLookupAssociation.h"
#include "SoObject.h"
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@implementation SoLookupAssociation

+ (int)version {
  return [super version] /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithTraversalPath:(NSArray *)_tp acquire:(BOOL)_ac {
  if ((self = [super init])) {
    self->traversalPath = [_tp copy];
    self->acquire = _ac;
  }
  return self;
}

- (id)initWithString:(NSString *)_s {
  BOOL acq;
  
  if ((acq = [_s hasPrefix:@"+"]))
    _s = [_s substringFromIndex:1];
  
  return [self initWithTraversalPath:[_s pathComponents] acquire:acq];
}

- (void)dealloc {
  [self->traversalPath release];
  [super dealloc];
}

/* accessors */

- (NSArray *)traversalPath {
  return self->traversalPath;
}
- (BOOL)doesAcquire {
  return self->acquire;
}

/* value */

- (BOOL)isValueConstant {
  return NO;
}
- (BOOL)isValueSettable {
  return NO;
}

/* op */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  // not settable
  [NSException raise:@"AssociationException"
               format:@"association value is not settable !"];
}

- (id)valueInComponent:(WOComponent *)_component {
  return [_component traversePathArray:self->traversalPath 
		     acquire:self->acquire];
}

@end /* SoLookupAssociation */
