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

#include "NGInternetSocketDomain.h"
#include "NGInternetSocketAddress.h"
#include "common.h"

#ifndef __MINGW32__
#  include <netinet/in.h>
#endif

@implementation NGInternetSocketDomain

static NGInternetSocketDomain *domain = nil;

+ (int)version {
  return 1;
}
+ (void)initialize {
  if (domain == nil) domain = [[NGInternetSocketDomain alloc] init];
}
+ (id)domain {
  return domain;
}

/* NGSocketDomain */

- (id<NGSocketAddress>)addressWithRepresentation:(void *)_data
  size:(unsigned int)_size
{
  NGInternetSocketAddress *address = nil;
  
  if ((unsigned int)[self addressRepresentationSize] != _size) {
    NSLog(@"%@: invalid address size %i ..", NSStringFromSelector(_cmd), _size);
    return nil;
  }
  
  address = [[NGInternetSocketAddress allocWithZone:[self zone]]
                                      initWithDomain:self
                                      internalRepresentation:_data
                                      size:_size];
  return [address autorelease];
}

- (BOOL)prepareAddress:(id<NGSocketAddress>)_address
  forBindWithSocket:(id<NGSocket>)_socket
{
  // nothing to prepare
  return YES;
}
- (BOOL)cleanupAddress:(id<NGSocketAddress>)_address
  afterCloseOfSocket:(id<NGSocket>)_socket
{
  // nothing to cleanup
  return YES;
}

- (int)socketDomain {
  return AF_INET;
}

- (int)addressRepresentationSize {
  return sizeof(struct sockaddr_in);
}

- (int)protocol {
  return 0;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* domain objects are immutable, just retain on copy */
  return [self retain];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
}
- (id)initWithCoder:(NSCoder *)_decoder {
  [self release]; self = nil;
  return [domain retain];
}

- (id)awakeAfterUsingCoder:(NSCoder *)_decoder {
  if (self != domain) {
    [self release]; self = nil;
    return [domain retain];
  }
  else
    return self;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<InternetDomain[0x%p]>", self];
}

@end /* NGInternetSocketDomain */
