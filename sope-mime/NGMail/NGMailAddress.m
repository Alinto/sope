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

#include "NGMailAddress.h"
#include "common.h"

@implementation NGMailAddress

+ (int)version {
  return 2;
}

+ (id)mailAddressWithAddress:(NSString *)_address
  displayName:(NSString *)_owner
  route:(NSString *)_route
{
  return [[[NGMailAddress alloc] initWithAddress:_address
                                 displayName:_owner
                                 route:_route] autorelease];
}

- (id)initWithAddress:(NSString *)_address
  displayName:(NSString *)_owner
  route:(NSString *)_route
{
  if ((self = [self init])) {
    NSZone *zone = [self zone];
    self->address     = [_address copyWithZone:zone];
    self->displayName = [_owner   copyWithZone:zone];
    self->route       = [_route   copyWithZone:zone];
  }
  return self;
}

- (void)dealloc {
  [self->address     release];
  [self->displayName release];
  [self->route       release];
  [super dealloc];  
}

/* equality */

- (BOOL)isEqual:(id)_anObject {
  if ([_anObject isKindOfClass:[NGMailAddress class]]) {
    NGMailAddress *a = _anObject;
    
    return (([self->address     isEqualToString:[a address]])   &&
            ([self->displayName isEqualToString:[a displayName]]) &&
            ([self->route       isEqualToString:[a route]]));
  }
  return NO;
}

- (unsigned)hash {
  return [self->address hash];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
  [_encoder encodeObject:address]; 
  [_encoder encodeObject:displayName];
  [_encoder encodeObject:route];  
}

- (id)initWithCoder:(NSCoder *)_decoder {
  id _address, _displayName, _route;
  
  _address     = [_decoder decodeObject];
  _displayName = [_decoder decodeObject];
  _route       = [_decoder decodeObject];
  return [self initWithAddress:_address 
               displayName:_displayName 
               route:_route];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[NGMailAddress allocWithZone:_zone] initWithAddress:self->address
                                              displayName:self->displayName
                                              route:self->route];
}
- (id)copy {
  return [self copyWithZone:[self zone]];
}

/* accessors */

- (void)setAddress:(NSString *)_string {
  ASSIGN(self->address, _string);
}
- (NSString *)address {
  return self->address;
}

- (void)setDisplayName:(NSString *)_displayName {
  ASSIGN(self->displayName, _displayName);
}
- (NSString *)displayName {
 return self->displayName;
}

- (void)setRoute:(NSString *)_route {
  ASSIGN(self->route, _route);
}
- (NSString *)route {
  return self->route;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"\"%s\" <%s> | route: %s",
                     [self->displayName cString],
                     [self->address     cString],
                     [self->route       cString]];
}

@end /* NGMailAddress */
