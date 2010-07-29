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

#include "NGPassiveSocket.h"
#include "NGSocketExceptions.h"
#include "NGActiveSocket.h"
#include "NGSocket+private.h"

#if defined(__APPLE__)
#  include <sys/types.h>
#  include <sys/socket.h>
#endif

#if HAVE_SYS_ERRNO_H || defined(__APPLE__)
#  include <sys/errno.h>
#endif

#include "common.h"

@interface NGActiveSocket(privateMethods)

- (id)_initWithDescriptor:(int)_fd
  localAddress:(id<NGSocketAddress>)_local
  remoteAddress:(id<NGSocketAddress>)_remote;

@end

@implementation NGPassiveSocket

+ (id)socketBoundToAddress:(id<NGSocketAddress>)_address {
  volatile id sock;
  
  sock = [[[self alloc] initWithDomain:[_address domain]] autorelease];
  [sock bindToAddress:_address];
  return sock;
}

- (id)initWithDomain:(id<NGSocketDomain>)_domain { // designated initializer
  if ((self = [super initWithDomain:_domain])) {
    backlogSize = -1; // -1 means 'not listening'
    
    if ([NSThread isMultiThreaded])
      acceptLock = [[NSLock allocWithZone:[self zone]] init];
    else {
      acceptLock = nil;
      [[NSNotificationCenter defaultCenter]
                             addObserver:self
                             selector:@selector(taskNowMultiThreaded:)
                             name:NSWillBecomeMultiThreadedNotification
                             object:nil];
    }

    if (self->fd != NGInvalidSocketDescriptor) {
      int i_yes = 1;
      
      if (setsockopt(self->fd, SOL_SOCKET, SO_REUSEADDR,
                     (void *)&i_yes, sizeof(int)) != 0) {
        NSLog(@"WARNING: could not set SO_REUSEADDR option for socket %@: %s",
              self, strerror(errno));
      }
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
                         removeObserver:self
                         name:NSWillBecomeMultiThreadedNotification
                         object:nil];
  
  [self->acceptLock release];
  [super dealloc];
}

- (void)taskNowMultiThreaded:(NSNotification *)_notification {
  if (acceptLock == nil) acceptLock = [[NSLock alloc] init];
}

// accessors

- (BOOL)isListening {
  return (backlogSize != -1);
}
- (BOOL)isOpen {
  return [self isListening];
}

- (id<NGSocketAddress>)localAddress {
  return localAddress;
}

- (int)socketType {
  return SOCK_STREAM;
}

/* operations */

#if defined(WIN32) && !defined(__CYGWIN32__)
- (NSString *)reasonForLastError {
  int errorCode = WSAGetLastError();

  switch (errorCode) {
    case WSAEBADF:
      return @"not a valid socket descriptor";
    case WSAENOTSOCK:
      return @"descriptor is not a socket descriptor";
    case WSAEOPNOTSUPP:
      return @"socket does not support listen";
    case WSAEINTR:
      return @"interrupted by signal";
    case WSAEMFILE:
      return @"descriptor table is full";

    default:
      return [NSString stringWithCString:strerror(errorCode)];
  }
}
#else
- (NSString *)reasonForLastError {
  int errorCode = errno;
  
  switch (errorCode) {
    case EBADF:
      return @"not a valid socket descriptor";
    case ENOTSOCK:
      return @"descriptor is not a socket descriptor";
    case EOPNOTSUPP:
      return @"socket does not support listen";
    case EINTR:
      return @"interrupted by signal";
    case EMFILE:
      return @"descriptor table is full";
    case EPROTONOSUPPORT:
      return @"The protocol is not supported by the address family or "
             @"implementation";
    case EPROTOTYPE:
      return @"The socket type is not supported by the protocol";

    default:
      return [NSString stringWithCString:strerror(errorCode)];
  }
}
#endif

- (BOOL)listenWithBacklog:(int)_backlogSize {
  // throws
  //   NGSocketIsAlreadyListeningException  when the socket is in the listen state
  //   NGCouldNotListenException            when the listen call failed
  
  if ([self isListening]) {
    [[[NGSocketIsAlreadyListeningException alloc]
              initWithReason:@"already called listen" socket:self] raise];
    return NO;
  }

  if (listen([self fileDescriptor], _backlogSize) != 0) {
    NSString *reason;
    reason = [self reasonForLastError];
    reason = [@"Could not listen: %@" stringByAppendingString:reason];
    
    [[[NGCouldNotListenException alloc]
              initWithReason:reason socket:self] raise];
    return NO;
  }

  /* set backlog size (and mark socket as 'listening') */
  self->backlogSize = _backlogSize;
  return YES;
}

- (id<NGActiveSocket>)accept {
  // throws
  //   NGCouldNotAcceptException  when the socket is not listening
  //   NGCouldNotAcceptException  when the accept call failed

  id<NGActiveSocket> socket;
  *(&socket) = nil;
  
  if (![self isListening]) {
    [[[NGCouldNotAcceptException alloc]
              initWithReason:@"socket is not listening" socket:self] raise];
  }
  
  SYNCHRONIZED(self->acceptLock) {
    id<NGSocketAddress> local  = nil;
    id<NGSocketAddress> remote = nil;
    socklen_t len;
    char *data;
    int  newFd = NGInvalidSocketDescriptor;

    len   = [[self domain] addressRepresentationSize];
    data = calloc(1, len + 1);
    
    if ((newFd = accept(fd, (void *)data, &len)) == -1) {
      // call failed
      NSString *reason = nil;
      reason = [self reasonForLastError];
      reason = [@"Could not accept: " stringByAppendingString:reason];
      
      [[[NGCouldNotAcceptException alloc]
                initWithReason:reason socket:self] raise];
    }

    /* produce remote socket address object */
    remote = [[self domain] addressWithRepresentation:(void *)data
                            size:len];
    
    // getsockname if wildcard-IP-bind to get local IP address assigned
    // to the connection
    len = [[self domain] addressRepresentationSize];
    if (getsockname(newFd, (void *)data, &len) != 0) { // function is MT-safe
      [[[NGSocketException alloc]
                initWithReason:@"could not get local socket name" socket:self]
                raise];
    }
    local = [[self domain] addressWithRepresentation:(void *)data size:len];

    if (data) {
      free(data);
      data = NULL;
    }
    
    socket = [[NGActiveSocket alloc]
                              _initWithDescriptor:newFd
                              localAddress:local
                              remoteAddress:remote];
    socket = [socket autorelease];
  }
  END_SYNCHRONIZED;
  return socket;
}

// description

- (NSString *)description {
  return [NSString stringWithFormat:@"<PassiveSocket: address=%@>",
                     [self localAddress]];
}

@end /* NGPassiveSocket */
