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

#if !defined(WIN32)

#include "NGLocalSocketDomain.h"
#include "NGLocalSocketAddress.h"
#include "NGSocket.h"

#if defined(__APPLE__) || defined(__FreeBSD__)
#  include <sys/types.h>
#  include <sys/socket.h>
#else
#  include <sys/un.h>
#endif

#include "common.h"

@implementation NGLocalSocketDomain

static NGLocalSocketDomain *domain = nil;

+ (void)initialize {
  BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;
    [NGSocket initialize];
    domain = [[NGLocalSocketDomain alloc] init];
  }
}
  
+ (id)domain {
  return domain;
}

// NGSocketDomain

- (id<NGSocketAddress>)addressWithRepresentation:(void *)_data
  size:(unsigned int)_size
{
  NGLocalSocketAddress *address = nil;

  address = [[NGLocalSocketAddress alloc] initWithDomain:self
                                          internalRepresentation:_data
                                          size:_size];
  return AUTORELEASE(address);
}

- (BOOL)prepareAddress:(id<NGSocketAddress>)_address
  forBindWithSocket:(id<NGSocket>)_socket
{
  if ([_socket conformsToProtocol:@protocol(NGPassiveSocket)]) {
    NSString *path = [(NGLocalSocketAddress *)_address path];

    // ignore errors ..
    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
  }
  return YES;
}
- (BOOL)cleanupAddress:(id<NGSocketAddress>)_address
  afterCloseOfSocket:(id<NGSocket>)_socket
{
  if ([_socket conformsToProtocol:@protocol(NGPassiveSocket)]) {
#if 0
    NSString *path = [(NGLocalSocketAddress *)_address path];

    // ignore errors ..
    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
#endif
  }
  return YES;
}

- (int)socketDomain {
  return AF_LOCAL;
}

- (int)addressRepresentationSize { // maximum size
  return sizeof(struct sockaddr_un);
}

- (int)protocol {
  return 0;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* domains are immutable, just return self on copy .. */
  return [self retain];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
}
- (id)initWithCoder:(NSCoder *)_decoder {
  [self release]; self = nil;
  return [domain retain]; /* replace with singleton */
}

- (id)awakeAfterUsingCoder:(NSCoder *)_decoder {
  if (self != domain) {
    [self release]; self = nil;
    return [domain retain]; /* replace with singleton */
  }
  else
    return self;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<UnixDomain: self=0x%p>", self];
}

@end /* NGLocalSocketDomain */

#endif // !WIN32
