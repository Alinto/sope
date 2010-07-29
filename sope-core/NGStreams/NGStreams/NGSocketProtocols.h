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

#ifndef __NGNet_NGSocketProtocols_H__
#define __NGNet_NGSocketProtocols_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGStreamProtocols.h>

@class NSException;

// addresses

@protocol NGSocketAddress < NSObject >

- (void *)internalAddressRepresentation;
- (int)addressRepresentationSize;
- (id)domain; // (a NGSocketDomain)

// needed by socket address factory:
- (id)initWithDomain:(id)_domain
  internalRepresentation:(void *)_representation
  size:(int)_length;

@end

// sockets

@protocol NGSocket < NSObject >

- (id<NGSocketAddress>)localAddress;
- (BOOL)bindToAddress:(id<NGSocketAddress>)_localAddress;
- (BOOL)close;

- (NSException *)lastException;

@end

// domains

@protocol NGSocketDomain < NSObject >

- (id<NGSocketAddress>)addressWithRepresentation:(void *)_data
  size:(unsigned int)_size;

- (int)socketDomain;
- (int)addressRepresentationSize;
- (int)protocol;

// these two methods manage resources associated with addresses
// (primarily the files used for AF_LOCAL sockets)
- (BOOL)prepareAddress:(id<NGSocketAddress>)_address
  forBindWithSocket:(id<NGSocket>)_socket;
- (BOOL)cleanupAddress:(id<NGSocketAddress>)_address
  afterCloseOfSocket:(id<NGSocket>)_socket;

@end

// concrete sockets

@protocol NGActiveSocket < NGSocket, NGStream, NGByteSequenceStream >

- (BOOL)connectToAddress:(id<NGSocketAddress>)_address;
- (BOOL)shutdown;

- (BOOL)isConnected;

- (id<NGSocketAddress>)remoteAddress;

@end

@protocol NGPassiveSocket < NGSocket >

- (BOOL)listenWithBacklog:(int)_backlogSize;
- (id<NGActiveSocket>)accept;

@end

// packets

@protocol NGDatagramPacket < NSObject >

- (void)setSender:(id<NGSocketAddress>)_address;
- (id<NGSocketAddress>)sender;
- (void)setReceiver:(id<NGSocketAddress>)_address;
- (id<NGSocketAddress>)receiver;

- (NSData *)data;

@end

@protocol NGDatagramPacketFactory < NSObject >

- (id<NGDatagramPacket>)packetWithData:(NSData *)_data;

- (id<NGDatagramPacket>)
  packetWithBytes:(const void *)_bytes
  size:(int)_packetSize;

@end

#endif /* __NGNet_NGSocketProtocols_H__ */
