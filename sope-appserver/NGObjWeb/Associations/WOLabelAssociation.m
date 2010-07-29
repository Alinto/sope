/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "WOLabelAssociation.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOSession.h>
#include "common.h"

@implementation WOLabelAssociation

+ (int)version {
  return [super version] /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithKey:(NSString *)_key inTable:(NSString *)_table
  withDefaultValue:(NSString *)_default
{
  if ([_key length] == 0) {
    [self warnWithFormat:@"missing label key!"];
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    if ([_key hasPrefix:@"$"]) {
      self->flags.isKeyKeyPath = 1;
      _key = [_key substringFromIndex:1];
    }
    if ([_table hasPrefix:@"$"]) {
      self->flags.isTableKeyPath = 1;
      _table = [_table substringFromIndex:1];
    }
    if ([_default hasPrefix:@"$"]) {
      self->flags.isValueKeyPath = 1;
      _default = [_default substringFromIndex:1];
    }
    
    self->key          = [_key     copy];
    self->table        = [_table   copy];
    self->defaultValue = [_default copy];
  }
  return self;
}
- (id)init {
  return [self initWithKey:nil inTable:nil withDefaultValue:nil];
}

- (id)initWithString:(NSString *)_str {
  NSString *lKey, *lTable, *lVal;
  NSRange r;
  
  if ([_str length] == 0) {
    [self release];
    return nil;
  }
  
  r = [_str rangeOfString:@"/"];
  if (r.length > 0) {
    lTable = [_str substringToIndex:r.location];
    lKey   = [_str substringFromIndex:(r.location + r.length)];
  }
  else {
    lTable = nil;
    lKey   = _str;
  }
  lVal = lKey;
  
  return [self initWithKey:lKey inTable:lTable withDefaultValue:lVal];
}

- (void)dealloc {
  [self->table        release];
  [self->defaultValue release];
  [self->key          release];
  [super dealloc];
}

/* value */

- (void)setValue:(id)_value inComponent:(WOComponent *)_component {
  // not settable
  [NSException raise:@"AssociationException"
               format:@"association value is not settable !"];
}
- (id)valueInComponent:(WOComponent *)_component {
  WOResourceManager *rm;
  NSArray           *languages;
  WOContext         *ctx;
  NSString          *label;
  NSString          *lKey, *lTable, *lVal;

  /* lookup languages */
  
  ctx       = [_component context];
  languages = [ctx resourceLookupLanguages];

  /* find resource manager */
  
  if ((rm = [_component resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];
  if (rm == nil)
    [self warnWithFormat:@"missing resource manager!"];

  /* get parameters */
  
  lKey   = self->key;
  lTable = self->table;
  lVal   = self->defaultValue;
  if (self->flags.isKeyKeyPath)   lKey   = [_component valueForKeyPath:lKey];
  if (self->flags.isTableKeyPath) lTable = [_component valueForKeyPath:lTable];
  if (self->flags.isValueKeyPath) lVal   = [_component valueForKeyPath:lVal];

  /* lookup string */
  
  label = [rm stringForKey:lKey inTableNamed:lTable withDefaultValue:lVal
              languages:languages];
  return label;
}

- (BOOL)isValueConstant {
  return NO;
}
- (BOOL)isValueSettable {
  return NO;
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

  if (self->flags.isKeyKeyPath)
    [str appendFormat:@" key=%@",   self->key];
  else
    [str appendFormat:@" key='%@'", self->key];

  if (self->flags.isTableKeyPath)
    [str appendFormat:@" table=%@",   self->table];
  else
    [str appendFormat:@" table='%@'", self->table];

  if (self->flags.isValueKeyPath)
    [str appendFormat:@" def=%@",   self->defaultValue];
  else
    [str appendFormat:@" def='%@'", self->defaultValue];
  
  [str appendString:@">"];
  return str;
}

@end /* WOLabelAssociation */
