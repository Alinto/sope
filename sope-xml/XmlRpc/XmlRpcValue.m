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

#include "XmlRpcValue.h"
#include "common.h"

@implementation XmlRpcValue
/*"
  The XmlRpcValue class is used internally by the XML-RPC decoder to
  represent any valid XML-RPC value. You should never need to use this class.
"*/

- (id)initWithValue:(id)_value className:(NSString *)_className {
  if ((self = [super init])) {
    NSString *cName;
    
    ASSIGN(self->value, _value);
    cName = (_className != nil)
      ? _className
      : NSStringFromClass([_value class]);

    ASSIGN(self->className, cName);
  }
  return self;
}

- (void)dealloc {
  [self->className release];
  [self->value     release];
  [super dealloc];
}

- (id)value {
  return self->value;
}

- (void)setClassName:(NSString *)_className {
  if (_className != self->className) {
    [self->className autorelease];
    self->className = [_className copy];
  }
}
- (NSString *)className {
  return self->className;
}

- (Class)class {
  return NSClassFromString([self className]);
}

- (BOOL)isException {
  return [(id<NSObject>)[self value] isKindOfClass:[NSException class]];
}
- (BOOL)isDictionary {
  return [(id<NSObject>)[self value] isKindOfClass:[NSDictionary class]];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"XmlRpcValue: %@->%@",
                   self->className,
                   self->value];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] alloc]
                 initWithValue:self->value className:self->className];
}

@end /* XmlRpcValue */
