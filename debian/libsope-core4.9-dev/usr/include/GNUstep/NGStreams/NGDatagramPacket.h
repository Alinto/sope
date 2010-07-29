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

#ifndef __NGNet_NGDatagramPacket_H__
#define __NGNet_NGDatagramPacket_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGSocketProtocols.h>

@class NSData;

/*
  This class represents an UDP datagram. It contains the addresses of it's sender
  and it's receiver.
*/

@interface NGDatagramPacket : NSObject < NGDatagramPacket >
{
@protected
  id<NGSocketAddress> sender;
  id<NGSocketAddress> receiver;
  NSData              *packet;
}

// packet factory

+ (id)packetWithData:(NSData *)_data;
+ (id)packetWithBytes:(const void *)_bytes size:(int)_packetSize;

- (id)initWithBytes:(const void *)_bytes size:(int)_size;
- (id)initWithData:(NSData *)_data;

// accessors

- (void)setSender:(id<NGSocketAddress>)_address;
- (id<NGSocketAddress>)sender;
- (void)setReceiver:(id<NGSocketAddress>)_address;
- (id<NGSocketAddress>)receiver;

- (void)setData:(NSData *)_data;
- (NSData *)data;

- (int)packetSize;

// operations

- (void)reverseAddresses;

@end

#endif /* __NGNet_NGDatagramPacket_H__ */
