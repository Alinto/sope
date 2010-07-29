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

#ifndef __NGNet_NGActiveSocket_H__
#define __NGNet_NGActiveSocket_H__

#import <Foundation/NSDate.h>
#include <NGStreams/NGSocket.h>
#include <NGStreams/NGSocketProtocols.h>
#include <NGStreams/NGStreamProtocols.h>

@class NSData, NSFileHandle;

/*
  Represents an active STREAM socket based on the standard Unix sockets
  library.

  An active socket can be either a socket gained by calling accept with an
  passive socket or by explicitly connecting one to an address (a client
  socket).
  Therefore an active socket has two addresses, the local and the remote one.

  There are three methods to perform a close, this is rooted in the fact that
  a socket actually is full-duplex, it provides a send and a receive channel.
  The stream-mode is updated according to what channels are open/closed.
  Initially the socket is full-duplex and you cannot reopen a channel that was
  shutdown. If you have shutdown both channels the socket can be considered
  closed.
*/

@interface NGActiveSocket : NGSocket < NGActiveSocket >
{
@private
  id<NGSocketAddress> remoteAddress;
  NGStreamMode        mode;
  
  NSTimeInterval receiveTimeout;
  NSTimeInterval sendTimeout;
}

+ (id)socketConnectedToAddress:(id<NGSocketAddress>)_address;
- (id)initWithDomain:(id<NGSocketDomain>)_domain; // designated initializer

#if !defined(WIN32)
+ (BOOL)socketPair:(id<NGSocket>[2])_pair;
#endif

// ******************** operations ********************

// throws
//   NGSocketAlreadyConnectedException  when the socket is already connected
//   NGInvalidSocketDomainException     when the remote domain != local domain
//   NGCouldNotCreateSocketException    if the socket creation failed
- (BOOL)connectToAddress:(id<NGSocketAddress>)_address;

- (BOOL)shutdown; // do a complete shutdown
- (BOOL)shutdownSendChannel;
- (BOOL)shutdownReceiveChannel;

// ******************** accessors *********************

- (id<NGSocketAddress>)remoteAddress;
- (BOOL)isConnected;
- (BOOL)isOpen;

- (void)setSendTimeout:(NSTimeInterval)_timeout;
- (NSTimeInterval)sendTimeout;
- (void)setReceiveTimeout:(NSTimeInterval)_timeout;
- (NSTimeInterval)receiveTimeout;

// test whether a read, a write or both would block the thread (using select)
- (BOOL)wouldBlockInMode:(NGStreamMode)_mode;
- (int)waitForMode:(NGStreamMode)_mode timeout:(NSTimeInterval)_timeout;
- (unsigned)numberOfAvailableBytesForReading;
- (BOOL)isAlive;

// ******************** NGStream **********************

// throws
//   NGStreamReadErrorException    when the read call failed
//   NGSocketNotConnectedException when the socket is not connected
//   NGEndOfStreamException        when the end of the stream is reached
- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;

// throws
//   NGStreamWriteErrorException   when the write call failed
//   NGSocketNotConnectedException when the socket is not connected
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;

- (BOOL)flush;                  // does nothing, sockets are unbuffered
- (NGStreamMode)mode;           // returns read/write

- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len;
- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len;

@end

@interface NGActiveSocket(DataMethods)

- (NSData *)readDataOfLength:(unsigned int)_length;
- (NSData *)safeReadDataOfLength:(unsigned int)_length;
- (unsigned int)writeData:(NSData *)_data;
- (BOOL)safeWriteData:(NSData *)_data;

@end

#endif /* __NGNet_NGActiveSocket_H__ */
