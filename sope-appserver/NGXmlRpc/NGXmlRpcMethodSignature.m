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

#include "NGXmlRpcMethodSignature.h"
#include "common.h"

@implementation NGXmlRpcMethodSignature

+ (id)signatureWithXmlRpcTypes:(NSArray *)_args {
  return [[[self alloc] initWithXmlRpcTypes:_args] autorelease];
}
- (id)initWithXmlRpcTypes:(NSArray *)_arg {
  if (![_arg isNotEmpty]) {
    RELEASE(self);
    return nil;
  }
  self->signature = [_arg copy];
  return self;
}
- (id)init {
  return [self initWithXmlRpcTypes:nil];
}

- (unsigned)numberOfArguments {
  return ([self->signature count] - 1);
}

- (NSString *)argumentTypeAtIndex:(unsigned int)_idx {
  return [self->signature objectAtIndex:(_idx + 1)];
}

- (NSString *)methodReturnType {
  return [self->signature objectAtIndex:0];
}

- (BOOL)isOneway {
  return NO;
}

- (NSArray *)xmlRpcTypes {
  return self->signature;
}

@end /* NGXmlRpcMethodSignature */
