/*
  Copyright (C) 2003-2004 SKYRIX Software AG

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

#include "NGRuleAssignment.h"
#include "common.h"

@implementation NGRuleAssignment

+ (id)assignmentWithKeyPath:(NSString *)_kp value:(id)_value {
  return [[[self alloc] initWithKeyPath:_kp value:_value] autorelease];
}
- (id)initWithKeyPath:(NSString *)_kp value:(id)_value {
  if ((self = [super init])) {
    self->keyPath = [_kp copy];
    self->value   = [_value retain];
  }
  return self;
}
- (id)init {
  return [self initWithKeyPath:nil value:nil];
}

- (void)dealloc {
  [self->keyPath release];
  [self->value   release];
  [super dealloc];
}

/* accessors */

- (void)setKeyPath:(NSString *)_kp {
  ASSIGNCOPY(self->keyPath, _kp);
}
- (NSString *)keyPath {
  return self->keyPath;
}

- (void)setValue:(id)_value {
  ASSIGN(self->value, _value);
}
- (id)value {
  return self->value;
}

/* operations */

- (BOOL)isCandidateForKey:(NSString *)_key {
  if (_key == nil) return YES;
  
  // TODO: perform a real keypath check
  return [self->keyPath isEqualToString:_key];
}

- (id)fireInContext:(id)_ctx {
  // TODO: shouldn't we apply the value on ctx ?
  return self->value;
}

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  return [self initWithKeyPath:[_unarchiver decodeObjectForKey:@"keyPath"]
	       value:[_unarchiver decodeObjectForKey:@"value"]];
}
- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  [_archiver encodeObject:[self keyPath] forKey:@"keyPath"];
  [_archiver encodeObject:[self value]   forKey:@"value"];
}

/* description */

- (NSString *)valueStringValue {
  NSMutableString *ms;

  if ([self->value isKindOfClass:[NSNumber class]])
    return [self->value stringValue];

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendString:@"\""];
  [ms appendString:[self->value stringValue]];
  [ms appendString:@"\""];
  return ms;
}

- (NSString *)stringValue {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendString:[[self keyPath] description]];
  [ms appendString:@" = "];
  [ms appendString:[self valueStringValue]];
  return ms;
}

- (NSString *)description {
  return [self stringValue];
}

@end /* NGRuleAssignment */


@implementation NGRuleKeyAssignment

/* operations */

- (id)fireInContext:(id)_ctx {
  // TODO: shouldn't we apply the value on ctx ?
  return [_ctx valueForKeyPath:[[self value] stringValue]];
}

/* description */

- (NSString *)valueStringValue {
  return [self->value stringValue];
}

@end /* NGRuleKeyAssignment */
