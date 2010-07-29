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

#ifndef __NGNet_NGDatagramSocket_H__
#define __NGNet_NGDatagramSocket_H__

#import <Foundation/NSDate.h>
#include <NGStreams/NGSocket.h>
#include <NGStreams/NGSocketProtocols.h>

/*
  Represents an UDP socket. UDP is a protocol based on IP, it's major 
  difference to TCP is that UDP is connectionless and unreliable (UDP
  datagrams send are not guaranteed to reach their destination).
  
  Note that you can connect an UDP socket. However, this only sets a 'default'
  target address, an UDP socket can be connected multiple times, therefore
  changing the default target. You can still use the send methods which take
  a target when the socket is connected.

  With UDP you do not have a distinction between active and passive sockets 
  (you cannot put an UDP socket in the listen-state). A socket becomes a 
  server socket by calling receive, which blocks the thread until a datagram 
  is available and it becomes a client socket by calling send. However to send
  datagrams you have to know the target address of the server-socket. This is
  usually acomplished by binding the socket to a well-known address.

  The receive packet methods take a timeout argument. The timeout is 
  accomplished by using a poll call that waits for read and timeout. A timeout 
  of 0 specifies that no timeout is used, that means the thread will block if 
  no data is available.
  When receiving a packet the socket needs to know the maximum packet size. 
  While packets may be bigger than the maximum size, the additional bytes are
  discarded.
  If the packet size is known you should use receivePacketWithMaxSize: instead
  of receivePacket. If the packet size is always the same, set the maximum
  packet size and use receivePacket.
*/

extern NSString *NGSocketTimedOutNotificationName;

@interface NGDatagramSocket : NGSocket
{
  id<NGDatagramPacketFactory> packetFactory;
  int maxPacketSize; // default = 2048
  struct {
    BOOL isConnected:1;
  } udpFlags;
}

+ (id)socketBoundToAddress:(id<NGSocketAddress>)_address;

#if !defined(WIN32)
+ (BOOL)socketPair:(id<NGSocket>[2])_pair;
#endif

// accessors

- (void)setMaxPacketSize:(int)_maxPacketSize;
- (int)maxPacketSize;

- (void)setPacketFactory:(id<NGDatagramPacketFactory>)_factory;
- (id<NGDatagramPacketFactory>)packetFactory;

- (int)socketType; // returns SOCK_DGRAM

// polling

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode;

// sending

// returns NO on timeout
- (BOOL)sendPacket:(id<NGDatagramPacket>)_packet timeout:(NSTimeInterval)_timeout;
// blocks until data can be send
- (BOOL)sendPacket:(id<NGDatagramPacket>)_packet;

// receiving

- (id<NGDatagramPacket>)receivePacketWithMaxSize:(int)_maxPacketSize
  timeout:(NSTimeInterval)_timeout;
- (id<NGDatagramPacket>)receivePacketWithTimeout:(NSTimeInterval)_timeout;

- (id<NGDatagramPacket>)receivePacketWithMaxSize:(int)_maxPacketSize;
- (id<NGDatagramPacket>)receivePacket;

// ************************* options *************************
//
//   set methods throw NGCouldNotSetSocketOptionException
//   get methods throw NGCouldNotGetSocketOptionException

- (void)setBroadcast:(BOOL)_flag;
- (BOOL)doesBroadcast;

// aborts, only supported for TCP
- (void)setDebug:(BOOL)_flag; 
- (BOOL)doesDebug;

@end

#endif /* __NGNet_NGDatagramSocket_H__ */
