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

#include "NGDatagramPacket.h"
#include "common.h"

@implementation NGDatagramPacket

+ (id)packetWithData:(NSData *)_data {
  return [[[self alloc] initWithData:_data] autorelease];
}
+ (id)packetWithBytes:(const void *)_bytes size:(int)_packetSize {
  return [[[self alloc] initWithBytes:_bytes size:_packetSize] autorelease];
}

- (id)initWithBytes:(const void *)_bytes size:(int)_packetSize {
  return [self initWithData:[NSData dataWithBytes:_bytes length:_packetSize]];
}
- (id)initWithData:(NSData *)_data {
  if ((self = [self init])) {
    self->packet = [_data copyWithZone:[self zone]];
  }
  return self;
}

- (void)dealloc {
  [self->packet   release];
  [self->sender   release];
  [self->receiver release];
  [super dealloc];
}

/* accessors */

- (void)setSender:(id<NGSocketAddress>)_address {
  ASSIGN(self->sender, _address);
}
- (id<NGSocketAddress>)sender {
  return self->sender;
}

- (void)setReceiver:(id<NGSocketAddress>)_address {
  ASSIGN(self->receiver, _address);
}
- (id<NGSocketAddress>)receiver {
  return self->receiver;
}

- (void)setData:(NSData *)_data {
  ASSIGN(self->packet, _data);
}
- (NSData *)data {
  return self->packet;
}

- (int)packetSize {
  return [self->packet length];
}

/* operations */

- (void)reverseAddresses {
  id oldSender = [[self sender] retain];
  [self setSender:[self receiver]];
  [self setReceiver:oldSender];
  [oldSender release]; oldSender = nil;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: from=%@ to=%@ size=%i>",
                     NSStringFromClass([self class]), self,
                     [self sender], [self receiver], [self packetSize]];
}

@end /* NGDatagramPacket */
