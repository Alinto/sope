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

#if defined(__APPLE__)
#  include <sys/types.h>
#  include <sys/socket.h>
#endif

#include <NGStreams/NGDescriptorFunctions.h>
#include <NGStreams/NGLocalSocketAddress.h>
#include <NGStreams/NGLocalSocketDomain.h>
#include "NGDatagramSocket.h"
#include "NGDatagramPacket.h"
#include "NGSocketExceptions.h"
#include "NGSocket+private.h"
#include "common.h"

#if !defined(POLLRDNORM)
#  define POLLRDNORM POLLIN
#endif

NSString *NGSocketTimedOutNotificationName = @"NGSocketTimedOutNotification";

@interface NGSocket(privateMethods)

- (void)_createSocketInDomain:(int)_domain;

- (void)setOption:(int)_option level:(int)_level value:(void *)_value len:(int)_len;
- (void)setOption:(int)_option value:(void *)_value len:(int)_len;
- (void)getOption:(int)_option level:(int)_level value:(void *)_val len:(int *)_len;
- (void)getOption:(int)_option value:(void *)_value len:(int *)_len;

@end

//static const int NGMaxTimeout = (int)-1;
static const NSTimeInterval NGNoTimeout = 0.0;

@implementation NGDatagramSocket

#if !defined(WIN32) || defined(__CYGWIN32__)

+ (BOOL)socketPair:(id<NGSocket>[2])_pair {
  int fds[2];
  NGLocalSocketDomain *domain;

  _pair[0] = nil;
  _pair[1] = nil;

  domain = [NGLocalSocketDomain domain];
  if (socketpair([domain socketDomain], SOCK_DGRAM, [domain protocol],
                 fds) == 0) {
    NGDatagramSocket *s1 = nil;
    NGDatagramSocket *s2 = nil;
    
    s1 = [[self alloc] _initWithDomain:domain descriptor:fds[0]];
    s2 = [[self alloc] _initWithDomain:domain descriptor:fds[1]];
    s1 = AUTORELEASE(s1);
    s2 = AUTORELEASE(s2);

    if ((s1 != nil) && (s2 != nil)) {
      _pair[0] = s1;
      _pair[1] = s2;

      return YES;
    }
    else
      return NO;
  }
  else {
    int      e       = errno;
    NSString *reason = nil;

    switch (e) {
      case EACCES:
        reason = @"Not allowed to create socket of this type";
        break;
      case ENOMEM:
        reason = @"Could not create socket: Insufficient user memory available";
        break;
      case EPROTONOSUPPORT:
        reason = @"The protocol is not supported by the address family or "
                 @"implementation";
        break;
      case EPROTOTYPE:
        reason = @"The socket type is not supported by the protocol";
        break;
      case EMFILE:
        reason = @"Could not create socket: descriptor table is full";
        break;
      case EOPNOTSUPP:
        reason = @"The specified protocol does not permit creation of socket "
                 @"pairs";
        break;

      default:
        reason = [NSString stringWithFormat:@"Could not create socketpair: %s",
                             strerror(e)];
        break;
    }
    [[[NGCouldNotCreateSocketException alloc]
              initWithReason:reason domain:domain] raise];
    return NO;
  }
}

#endif

+ (id)socketBoundToAddress:(id<NGSocketAddress>)_address {
  volatile id sock = [[self alloc] initWithDomain:[_address domain]];

  if (sock != nil) {
    sock = AUTORELEASE(sock);
    [sock bindToAddress:_address];
  }
  return sock;
}

- (id)initWithDomain:(id<NGSocketDomain>)_domain { // designated initializer
  if ((self = [super initWithDomain:_domain])) {
    [self setMaxPacketSize:2048];
    [self setPacketFactory:(id)[NGDatagramPacket class]];
    self->udpFlags.isConnected = NO;
  }
  return self;
}

// accessors

- (void)setMaxPacketSize:(int)_maxPacketSize {
  self->maxPacketSize = _maxPacketSize;
}
- (int)maxPacketSize {
  return self->maxPacketSize;
}

- (void)setPacketFactory:(id<NGDatagramPacketFactory>)_factory {
  ASSIGN(self->packetFactory, _factory);
}
- (id<NGDatagramPacketFactory>)packetFactory {
  return self->packetFactory;
}

- (int)socketType {
  return SOCK_DGRAM;
}

- (BOOL)isConnected {
  return self->udpFlags.isConnected;
}

// polling

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode {
  short events = 0;

  if (fd == NGInvalidSocketDescriptor)
    return NO;

  if (NGCanReadInStreamMode(_mode))  events |= POLLRDNORM;
  if (NGCanWriteInStreamMode(_mode)) events |= POLLWRNORM;

  // timeout of 0 means return immediatly
  return (NGPollDescriptor([self fileDescriptor], events, 0) == 1 ? NO : YES);
}

// sending

- (void)primarySendPacket:(id<NGDatagramPacket>)_packet {
  int bytesWritten;

  NSAssert([_packet receiver], @"packet has no destination !");

  bytesWritten = sendto(self->fd, // socket
                        [[_packet data] bytes], [[_packet data] length],
                        0, // flags
                        [[_packet receiver] internalAddressRepresentation],
                        [[_packet receiver] addressRepresentationSize]);

  if (!self->flags.isBound) // was not explictly bound, so get local address
    [self kernelBoundAddress];

  [_packet setSender:[self localAddress]];
}

- (BOOL)sendPacket:(id<NGDatagramPacket>)_packet timeout:(NSTimeInterval)_to {
  if (_to > NGNoTimeout) {
    int result = NGPollDescriptor([self fileDescriptor],
                                  POLLWRNORM,
                                  (int)(_to * 1000.0));

    if (result == 0) {
      // timeout
      [[NSNotificationCenter defaultCenter]
                             postNotificationName:NGSocketTimedOutNotificationName
                             object:self];
      return NO;
    }
    else if (result < 0) {
      [[[NGSocketException alloc]
           initWithReason:@"error during poll on UDP socket"] raise];
      return NO;
    }

    // else receive packet ..
  }
  [self primarySendPacket:_packet];
  return YES;
}

- (BOOL)sendPacket:(id<NGDatagramPacket>)_packet {
  return [self sendPacket:_packet timeout:NGNoTimeout];
}

// receiving

- (id<NGDatagramPacket>)primaryReceivePacketWithMaxSize:(int)_maxSize {
  id<NGSocketAddress>  remote  = nil;
  id<NGDatagramPacket> packet = nil;
  char         buffer[_maxSize];
  size_t       size;
  unsigned int len   = [[self domain] addressRepresentationSize];
  char         data[len + 2];

  size = recvfrom(self->fd, buffer, _maxSize,
                  0, // flags
                  (void *)data, &len);
  remote = [[self domain] addressWithRepresentation:(void *)data size:len];

  if (!self->flags.isBound) // was not explictly bound, so get local address
    [self kernelBoundAddress];

  packet = [[self packetFactory] packetWithBytes:buffer size:size];
  [packet setReceiver:[self localAddress]];
  [packet setSender:remote];

  return packet;
}
- (id<NGDatagramPacket>)receivePacketWithMaxSize:(int)_size
  timeout:(NSTimeInterval)_to {
  
  if (_to > NGNoTimeout) {
    int result = NGPollDescriptor([self fileDescriptor],
                                  POLLRDNORM,
                                  (int)(_to * 1000.0));

    if (result == 0) {
      // timeout
      [[NSNotificationCenter defaultCenter]
                             postNotificationName:NGSocketTimedOutNotificationName
                             object:self];
      return nil;
    }
    else if (result < 0) {
      [[[NGSocketException alloc]
           initWithReason:@"error during poll on UDP socket"] raise];
    }

    // else receive packet ..
  }
  return [self primaryReceivePacketWithMaxSize:_size];
}

- (id<NGDatagramPacket>)receivePacketWithTimeout:(NSTimeInterval)_timeout {
  return [self receivePacketWithMaxSize:[self maxPacketSize] timeout:_timeout];
}

- (id<NGDatagramPacket>)receivePacketWithMaxSize:(int)_maxPacketSize {
  return [self receivePacketWithMaxSize:_maxPacketSize timeout:NGNoTimeout];
}
- (id<NGDatagramPacket>)receivePacket {
  return [self receivePacketWithMaxSize:[self maxPacketSize] timeout:NGNoTimeout];
}

// ************************* options *************************

static int i_yes = 1;
static int i_no  = 0;

static inline void setBoolOption(id self, int _option, BOOL _flag) {
  [self setOption:_option level:SOL_SOCKET
        value:(_flag ? &i_yes : &i_no) len:4];
}
static inline BOOL getBoolOption(id self, int _option) {
  int value, len;
  [self getOption:_option level:SOL_SOCKET value:&value len:&len];
  return (value ? YES : NO);
}

- (void)setBroadcast:(BOOL)_flag {
  setBoolOption(self, SO_BROADCAST, _flag);
}
- (BOOL)doesBroadcast {
  return getBoolOption(self, SO_BROADCAST);
}

// aborts, only supported for TCP

- (void)setDebug:(BOOL)_flag {
  [self doesNotRecognizeSelector:_cmd];
}
- (BOOL)doesDebug {
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

@end
