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

#include "WOValueAssociation.h"
#include "common.h"

// TODO: check whether it makes sense to precalculate int/bool/?? values
//       from the object value (add counters on how often these are called)

@implementation WOValueAssociation

static Class StrClass = Nil;

+ (int)version {
  return [super version] /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  StrClass = [NSString class];
}

+ (WOAssociation *)associationWithValue:(id)_value {
  return [[[WOValueAssociation alloc] initWithValue:_value] autorelease];
}

- (id)init {
  return [self initWithValue:nil];
}
- (id)initWithValue:(id)_value {
  if ((self = [super init])) {
    self->value = [_value retain]; /* do not use copy, can be full objects */
  }
  return self;
}
- (id)initWithString:(NSString *)_s {
  return [self initWithValue:_s];
}

- (void)dealloc {
  [self->value release];
  [super dealloc];
}

/* value */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  // not settable
  [NSException raise:@"AssociationException"
               format:@"association value is not settable !"];
}
- (id)valueInComponent:(WOComponent *)_component {
  return self->value;
}

- (BOOL)isValueConstant {
  return YES;
}
- (BOOL)isValueSettable {
  return NO;
}

/* special values */

- (unsigned int)unsignedIntValueInComponent:(WOComponent *)_component {
  register unsigned int val;
  
  if (self->cacheFlags.hasSmallValue)
    return self->cacheFlags.smallValue;
  
  val = [self->value unsignedIntValue];
  if (self->cacheFlags.hasNoSmallValue)
    return val;
  
  if (val < 65536) {
    self->cacheFlags.smallValue = val;
    self->cacheFlags.hasSmallValue = 1;
  }
  else
    self->cacheFlags.hasNoSmallValue = 1;
  return val;
}
- (int)intValueInComponent:(WOComponent *)_component {
  register int val;
  
  if (self->cacheFlags.hasSmallValue)
    return self->cacheFlags.smallValue;
  
  val = [self->value intValue];
  if (self->cacheFlags.hasNoSmallValue)
    return val;
  
  if (val >= 0 && val < 65536) {
    self->cacheFlags.smallValue = val;
    self->cacheFlags.hasSmallValue = 1;
  }
  else
    self->cacheFlags.hasNoSmallValue = 1;
  return val;
}
- (BOOL)boolValueInComponent:(WOComponent *)_component {
  switch (self->cacheFlags.boolValue) {
  case 1: return YES;
  case 2: return NO;
  default:
    if (self->value == nil)
      self->cacheFlags.boolValue = 2; /* false */
    else
      self->cacheFlags.boolValue = [self->value boolValue] ? 1 : 2;
    return self->cacheFlags.boolValue == 1 ? YES : NO;
  }
}
- (NSString *)stringValueInComponent:(WOComponent *)_component {
  return [self->value stringValue];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->value];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super init])) {
    self->value = [[_coder decodeObject] retain];
  }
  return self;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* description */

- (NSString *)description {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [str appendString:@" value="];
  if ([self->value isKindOfClass:StrClass]) {
    NSString *v = self->value;
    
    [str appendString:@"\""];
    if ([self->value length] > 10) {
      v = [v substringToIndex:9];
      v = [v stringByApplyingCEscaping];
      [str appendString:v];
      [str appendFormat:@"...[len=%i]", [self->value length]];
    }
    else {
      v = [v stringByApplyingCEscaping];
      [str appendString:v];
    }
    [str appendString:@"\""];
  }
  else {
    [str appendString:[self->value description]];
    [str appendFormat:@"(%@)", NSStringFromClass([self->value class])];
  }
  [str appendString:@">"];

  return str;
}

@end /* WOValueAssociation */

@implementation _WOBoolValueAssociation

static _WOBoolValueAssociation *yesAssoc = nil;
static _WOBoolValueAssociation *noAssoc  = nil;
static NSNumber *yesNum = nil;
static NSNumber *noNum  = nil;

+ (void)initialize {
  if (yesNum == nil) yesNum = [[NSNumber numberWithBool:YES] retain];
  if (noNum  == nil) noNum  = [[NSNumber numberWithBool:NO] retain];
}

+ (WOAssociation *)associationWithBool:(BOOL)_value {
  if (_value) {
    if (yesAssoc == nil) {
      yesAssoc = [[_WOBoolValueAssociation alloc] init];
      yesAssoc->value = YES;
    }
    return yesAssoc;
  }
  else {
    if (noAssoc == nil) {
      noAssoc = [[_WOBoolValueAssociation alloc] init];
      noAssoc->value = NO;
    }
    return noAssoc;
  }
}
+ (WOAssociation *)associationWithValue:(id)_value {
  return [self associationWithBool:[_value boolValue]];
}

/* value */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  // not settable
  [NSException raise:@"AssociationException"
               format:@"association value is not settable !"];
}
- (id)valueInComponent:(WOComponent *)_component {
  return self->value ? yesNum : noNum;
}

- (BOOL)isValueConstant {
  return YES;
}
- (BOOL)isValueSettable {
  return NO;
}

/* special values */

- (unsigned int)unsignedIntValueInComponent:(WOComponent *)_component {
  return self->value ? 1 : 0;
}
- (int)intValueInComponent:(WOComponent *)_component {
  return self->value ? 1 : 0;
}
- (BOOL)boolValueInComponent:(WOComponent *)_component {
  return self->value;
}
- (NSString *)stringValueInComponent:(WOComponent *)_component {
  return self->value ? @"YES" : @"NO";
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: %s",
                     NSStringFromClass([self class]), self,
                     self->value ? "YES" : "NO"];
}

@end /* _WOBoolValueAssociation */
