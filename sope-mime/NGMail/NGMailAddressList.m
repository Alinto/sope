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

#include "NGMailAddressList.h"
#include "common.h"

@implementation NGMailAddressList

+ (int)version {
  return 2;
}

+ (id)mailAddressListWithAddresses:(NSSet *)_addresses
  groupName:(NSString *)_groupName {
  return [[[NGMailAddressList alloc] initWithAddresses:_addresses
                                     groupName:_groupName] autorelease];
}

- (id)init {
  if ((self = [super init])) {
    self->addresses = [[NSMutableSet alloc] init];
  }
  return self;
}

- (id)initWithAddresses:(NSSet *)_addresses groupName:(NSString *)_groupName {
  if ((self = [self init])) {
    if (_addresses)
      [self->addresses unionSet:_addresses];
    self->groupName = [_groupName copy];;
  }
  return self;
}

- (void)dealloc {
  [self->addresses release];
  [self->groupName release];
  [super dealloc];
}

- (void)addAddress:(NGMailAddress *)_address {
  [self->addresses addObject:_address];
}

/* equality */

- (BOOL)isEqual:(id)_anObject {
  if ([_anObject isKindOfClass:[NGMailAddressList class]]) {
    BOOL  result = NO;
    NSSet *set   = nil;

    if (![self->groupName isEqualToString:[_anObject groupName]])
      return NO;

    set = [[NSSet alloc]
                  initWithObjectsFromEnumerator:
                    [(NGMailAddressList *)_anObject addresses]];
    result = [self->addresses isEqualToSet:set];
    [set release]; set = nil;
    return result;
  }
  return NO;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
  [_encoder encodeObject:self->addresses];
  [_encoder encodeObject:self->groupName];
}

- (id)initWithCoder:(NSCoder *)_decoder {
  id _addresses, _groupName;

  _addresses   = [_decoder decodeObject];
  _groupName   = [_decoder decodeObject];

  return [self initWithAddresses:_addresses groupName:_groupName];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[NGMailAddressList allocWithZone:_zone]
                             initWithAddresses:self->addresses
                             groupName:self->groupName];
}

/* accessors */

- (NSEnumerator *)addresses {
  return [self->addresses objectEnumerator];
}

- (void)setGroupName:(NSString *)_name {
  ASSIGN(self->groupName, _name);
}
- (NSString *)groupName {
 return self->groupName;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"GroupName: %s \n %@\n",
                     [self->groupName cString],
                     self->addresses];
}

@end /* NGMailAddressList */
