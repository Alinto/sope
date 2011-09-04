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

#include "config.h"

#if defined(HAVE_UNISTD_H) || defined(__APPLE__)
#  include <unistd.h>
#endif

#ifdef HAVE_SYS_SELECT_H
#  include <sys/select.h>
#endif
#ifdef HAVE_SYS_FILIO_H
#  include <sys/filio.h>
#endif
#if defined(HAVE_SYS_IOCTL_H)
#  include <sys/ioctl.h>
#endif
#if defined(HAVE_TIME_H) || defined(__APPLE__)
#  include <time.h>
#endif
#if defined(HAVE_SYS_TIME_H) || defined(__APPLE__)
#  include <sys/time.h>
#endif
#if defined(HAVE_FCNTL_H) || defined(__APPLE__)
#  include <fcntl.h>
#endif

#if defined(__APPLE__)
#  include <sys/types.h>
#  include <sys/socket.h>
#  include <sys/ioctl.h>
#endif

#if HAVE_WINDOWS_H && !defined(__CYGWIN32__)
#  include <windows.h>
#endif

#if defined(WIN32) && !defined(__CYGWIN32__)
#  include <winsock.h>
#  define ioctl ioctlsocket
#endif

#include "common.h"

#include <NGStreams/NGDescriptorFunctions.h>
#include <NGStreams/NGLocalSocketAddress.h>
#include <NGStreams/NGLocalSocketDomain.h>
#include "NGActiveSocket.h"
#include "NGSocketExceptions.h"
#include "NGSocket+private.h"
#include "common.h"

#if !defined(POLLRDNORM)
#  define POLLRDNORM POLLIN
#endif

@interface NGActiveSocket(PrivateMethods)

- (id)_initWithDescriptor:(int)_fd
  localAddress:(id<NGSocketAddress>)_local
  remoteAddress:(id<NGSocketAddress>)_remote;

@end

@implementation NGActiveSocket

#if !defined(WIN32) || defined(__CYGWIN32__)

+ (BOOL)socketPair:(id<NGSocket>[2])_pair {
  int fds[2];
  NGLocalSocketDomain *domain;

  _pair[0] = nil;
  _pair[1] = nil;

  domain = [NGLocalSocketDomain domain];
  if (socketpair([domain socketDomain], SOCK_STREAM, [domain protocol],
                 fds) == 0) {
    NGActiveSocket *s1 = nil;
    NGActiveSocket *s2 = nil;
    NGLocalSocketAddress *address;
    
    s1 = [[self alloc] _initWithDomain:domain descriptor:fds[0]];
    s2 = [[self alloc] _initWithDomain:domain descriptor:fds[1]];
    s1 = [s1 autorelease];
    s2 = [s2 autorelease];

    address = [NGLocalSocketAddress address];
    if ((s1 != nil) && (s2 != nil)) {
      s1->mode           = NGStreamMode_readWrite;
      s1->receiveTimeout = 0.0;
      s1->sendTimeout    = 0.0;
      ASSIGN(s1->remoteAddress, address);
      s2->mode           = NGStreamMode_readWrite;
      s2->receiveTimeout = 0.0;
      s2->sendTimeout    = 0.0;
      ASSIGN(s2->remoteAddress, address);

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

#if DEBUG
      case 0:
        NSLog(@"WARNING(%s): socketpair() call failed, but errno=0",
              __PRETTY_FUNCTION__);
#endif
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

+ (id)socketConnectedToAddress:(id<NGSocketAddress>)_address {
  volatile id sock = [[self alloc] initWithDomain:[_address domain]];
  
  if (sock != nil) {
    if (![sock connectToAddress:_address]) {
      NSException *e;
#if 0
      NSLog(@"WARNING(%s): Couldn't connect to address %@: %@",
            __PRETTY_FUNCTION__, _address, [sock lastException]);
#endif
      /*
        this method needs to raise the exception, since no object is returned
        in which we could check the -lastException ...
      */
      e = [[sock lastException] retain];
      [self release];
      e = [e autorelease];
      [e raise];
      return nil;
    }
    sock = [sock autorelease];
  }
  return sock;
}

- (id)initWithDomain:(id<NGSocketDomain>)_domain {
  // designated initializer
  if ((self = [super initWithDomain:_domain])) {
    self->mode           = NGStreamMode_readWrite;
    self->receiveTimeout = 0.0;
    self->sendTimeout    = 0.0;
  }
  return self;
}

- (id)_initWithDescriptor:(int)_fd
  localAddress:(id<NGSocketAddress>)_local
  remoteAddress:(id<NGSocketAddress>)_remote 
{
  if ((self = [self _initWithDomain:[_local domain] descriptor:_fd])) {
    ASSIGN(self->localAddress,  _local);
    ASSIGN(self->remoteAddress, _remote);
    self->mode = NGStreamMode_readWrite;
    
#if !defined(WIN32) || defined(__CYGWIN32__)
    NGAddDescriptorFlag(self->fd, O_NONBLOCK);
#endif
  }
  return self;
}

- (void)dealloc {
  [self->remoteAddress release];
  [super dealloc];
}

/* operations */

- (NSException *)lastException {
  return [super lastException];
}

- (void)raise:(NSString *)_name reason:(NSString *)_reason {
  Class clazz;
  NSException *e;
  
  clazz = NSClassFromString(_name);
  NSAssert1(clazz, @"did not find exception class %@", _name);
  
  e = [clazz alloc];
  if (_reason) {
    if ([clazz instancesRespondToSelector:@selector(initWithReason:socket:)])
      e = [(id)e initWithReason:_reason socket:self];
    else if ([clazz instancesRespondToSelector:@selector(initWithStream:reason:)])
      e = [(id)e initWithStream:self reason:_reason];
    else if ([clazz instancesRespondToSelector:@selector(initWithSocket:)])
      e = [(id)e initWithSocket:self];
    else if ([clazz instancesRespondToSelector:@selector(initWithStream:)])
      e = [(id)e initWithStream:self];
    else
      e = [e initWithReason:_reason];
  }
  else {
    if ([clazz instancesRespondToSelector:@selector(initWithSocket:)])
      e = [(id)e initWithSocket:self];
    else if ([clazz instancesRespondToSelector:@selector(initWithStream:)])
      e = [(id)e initWithStream:self];
    else
      e = [e init];
  }
  [self setLastException:e];
  [e release];
}
- (void)raise:(NSString *)_name {
  [self raise:_name reason:nil];
}

- (BOOL)markNonblockingAfterConnect {
#if !defined(WIN32) || defined(__CYGWIN32__)
  // mark socket as non-blocking
  return YES;
#else
  // on Win we only support blocking sockets right now ...
  return NO;
#endif
}

- (BOOL)primaryConnectToAddress:(id<NGSocketAddress>)_address {
  // throws
  //   NGCouldNotConnectException  if the the connect() call fails

  [self resetLastException];
  
  if (connect(fd,
              (struct sockaddr *)[_address internalAddressRepresentation],
              [_address addressRepresentationSize]) != 0) {
    NSString *reason   = nil;
    int      errorCode = errno;
    NSException *e;
    
    switch (errorCode) {
      case EACCES:
        reason = @"search permission denied for element in path";
        break;
#if defined(WIN32) && !defined(__CYGWIN32__)
      case WSAEADDRINUSE:
        reason = @"address already in use";
        break;
      case WSAEADDRNOTAVAIL:
        reason = @"address is not available on remote machine";
        break;
      case WSAEAFNOSUPPORT:
        reason = @"addresses in the specified family cannot be used with the socket";
        break;
      case WSAEALREADY:
        reason = @"a previous non-blocking attempt has not yet been completed";
        break;
      case WSAEBADF:
        reason = @"descriptor is invalid";
        break;
      case WSAECONNREFUSED:
        reason = @"connection refused";
        break;
      case WSAEINTR:
        reason = @"connect was interrupted";
        break;
      case WSAEINVAL:
        reason = @"the address length is invalid";
        break;
      case WSAEISCONN:
        reason = @"socket is already connected";
        break;
      case WSAENETUNREACH:
        reason = @"network is unreachable";
        break;
      case WSAETIMEDOUT:
        reason = @"timeout occured";
        break;
#else
      case EADDRINUSE:
        reason = @"address already in use";
        break;
      case EADDRNOTAVAIL:
        reason = @"address is not available on remote machine";
        break;
      case EAFNOSUPPORT:
        reason = @"addresses in the specified family cannot be used with the socket";
        break;
      case EALREADY:
        reason = @"a previous non-blocking attempt has not yet been completed";
        break;
      case EBADF:
        reason = @"descriptor is invalid";
        break;
      case ECONNREFUSED:
        reason = @"connection refused";
        break;
      case EINTR:
        reason = @"connect was interrupted";
        break;
      case EINVAL:
        reason = @"the address length is invalid";
        break;
      case EIO:
        reason = @"an IO error occured";
        break;
      case EISCONN:
        reason = @"socket is already connected";
        break;
      case ENETUNREACH:
        reason = @"network is unreachable";
        break;
      case ETIMEDOUT:
        reason = @"timeout occured";
        break;
#endif

#if DEBUG
      case 0:
        NSLog(@"WARNING(%s): connect() call failed, but errno=0",
              __PRETTY_FUNCTION__);
#endif
        
      default:
        reason = [NSString stringWithCString:strerror(errorCode)];
        break;
    }

    reason = [NSString stringWithFormat:@"Could not connect to address %@: %@",
                         _address, reason];
    
    e = [[NGCouldNotConnectException alloc]
              initWithReason:reason socket:self address:_address];
    [self setLastException:e];
    [e release];
    return NO;
  }
  
  /* connect was successful */

  ASSIGN(self->remoteAddress, _address);

  if ([self markNonblockingAfterConnect]) {
    /* mark socket as non-blocking */
    NGAddDescriptorFlag(self->fd, O_NONBLOCK);
    NSAssert((NGGetDescriptorFlags(self->fd) & O_NONBLOCK),
             @"could not enable non-blocking mode ..");
  }
  return YES;
}

- (BOOL)connectToAddress:(id<NGSocketAddress>)_address {
  // throws
  //   NGSocketAlreadyConnectedException  if the socket is already connected
  //   NGInvalidSocketDomainException     if the remote domain != local domain
  //   NGCouldNotCreateSocketException    if the socket creation failed
  
  if ([self isConnected]) {
    [[[NGSocketAlreadyConnectedException alloc]
              initWithReason:@"Could not connected: socket is already connected"
              socket:self address:self->remoteAddress] raise];
    return NO;
  }

  // check whether the remote address is in the same domain like the bound one
  if (flags.isBound) {
    if (![[localAddress domain] isEqual:[_address domain]]) {
      [[[NGInvalidSocketDomainException alloc]
                initWithReason:@"local and remote socket domains are different"
                socket:self domain:[_address domain]] raise];
      return NO;
    }
  }
  
  // connect, remote-address is non-nil if this returns
  if (![self primaryConnectToAddress:_address])
    return NO;

  // if the socket wasn't bound before (normal case), bind it now
  if (!flags.isBound)
    if (![self kernelBoundAddress]) return NO;
  return YES;
}

- (void)_shutdownDuringOperation {
  [self shutdown];
}

- (BOOL)shutdown {
  if (self->fd != NGInvalidSocketDescriptor) {
    if (self->mode != NGStreamMode_undefined) {
      if (shutdown(self->fd, SHUT_RDWR) == 0)
        self->mode = NGStreamMode_undefined;
    }
    
#if defined(WIN32) && !defined(__CYGWIN32__)
    if (closesocket(self->fd) == 0) {
#else
    if (close(self->fd) == 0) {
#endif
      self->fd = NGInvalidSocketDescriptor;
    }
    else {
      NSLog(@"ERROR(%s): close of socket %@ (fd=%i) alive=%s failed: %s",
            __PRETTY_FUNCTION__,
            self, self->fd, [self isAlive] ? "YES" : "NO", strerror(errno));
    }
    
    ASSIGN(self->remoteAddress, (id)nil);
  }
  return YES;
}

- (BOOL)shutdownSendChannel {
  if (NGCanWriteInStreamMode(self->mode)) {
    shutdown(self->fd, SHUT_WR);
    
    if (self->mode == NGStreamMode_readWrite)
      self->mode = NGStreamMode_readOnly;
    else {
      self->mode = NGStreamMode_undefined;
#if defined(WIN32) && !defined(__CYGWIN32__)
      closesocket(self->fd);
#else
      close(self->fd);
#endif
      self->fd = NGInvalidSocketDescriptor;
    }
  }
  return YES;
}
- (BOOL)shutdownReceiveChannel {
  if (NGCanReadInStreamMode(self->mode)) {
    shutdown(self->fd, SHUT_RD);
    
    if (self->mode == NGStreamMode_readWrite)
      self->mode = NGStreamMode_writeOnly;
    else {
      self->mode = NGStreamMode_undefined;
#if defined(WIN32) && !defined(__CYGWIN32__)
      closesocket(self->fd);
#else
      close(self->fd);
#endif
      self->fd = NGInvalidSocketDescriptor;
    }
  }
  return YES;
}

// ******************** accessors ******************

- (id<NGSocketAddress>)remoteAddress {
  return self->remoteAddress;
}

- (BOOL)isConnected {
  return (self->remoteAddress != nil);
}
- (BOOL)isOpen {
  return [self isConnected];
}

- (int)socketType {
  return SOCK_STREAM;
}

- (void)setSendTimeout:(NSTimeInterval)_timeout {
  struct timeval tv;

  if ([self isConnected]) {
    tv.tv_sec = (int) _timeout;
    tv.tv_usec = 0;
    setsockopt(self->fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof (struct timeval));
  }
  self->sendTimeout = _timeout;
}
- (NSTimeInterval)sendTimeout {
  return self->sendTimeout;
}

- (void)setReceiveTimeout:(NSTimeInterval)_timeout {
  struct timeval tv;

  if ([self isConnected]) {
    tv.tv_sec = (int) _timeout;
    tv.tv_usec = 0;
    setsockopt(self->fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof (struct timeval));
  }
  self->receiveTimeout = _timeout;
}
- (NSTimeInterval)receiveTimeout {
  return self->receiveTimeout;
}

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode {
  short events = 0;

  if ((![self isConnected]) || (fd == NGInvalidSocketDescriptor))
    return NO;

  if (NGCanReadInStreamMode(_mode))  events |= POLLRDNORM;
  if (NGCanWriteInStreamMode(_mode)) events |= POLLWRNORM;

  // timeout of 0 means return immediatly
  return (NGPollDescriptor([self fileDescriptor], events, 0) == 1 ? NO : YES);
}

- (int)waitForMode:(NGStreamMode)_mode timeout:(NSTimeInterval)_timeout {
  short events = 0;

  if (NGCanReadInStreamMode(_mode))  events |= POLLRDNORM;
  if (NGCanWriteInStreamMode(_mode)) events |= POLLWRNORM;

  // timeout of 0 means return immediatly
  return NGPollDescriptor([self fileDescriptor], events,
                          (int)(_timeout * 1000.0));
}

- (unsigned)numberOfAvailableBytesForReading {
  int len;

  // need to check whether socket is connected
  if (self->remoteAddress == nil) {
    [self raise:@"NGSocketNotConnectedException"
          reason:@"socket is not connected"];
    return NGStreamError;
  }
  
  if (!NGCanReadInStreamMode(self->mode)) {
    [self raise:@"NGWriteOnlyStreamException"];
    return NGStreamError;
  }
  
#if !defined(WIN32) && !defined(__CYGWIN32__)
  while (ioctl(self->fd, FIONREAD, &len) == -1) {
    if (errno == EINTR) continue;
    
    [self raise:@"NGSocketException"
          reason:@"could not get number of available bytes"];
    return NGStreamError;
  }
#else
  // PeekNamedPipe() on Win ...
  len = 0;
#endif
  return len;
}

- (BOOL)isAlive {
  if (self->fd == NGInvalidSocketDescriptor)
    return NO;
  
  /* poll socket for input */
  {
    struct timeval to;
    fd_set readMask;

    while (YES) {
      FD_ZERO(&readMask);
      FD_SET(self->fd, &readMask);
      to.tv_sec = to.tv_usec = 0;
      
      if (select(self->fd + 1, &readMask, NULL, NULL, &to) >= 0)
        break;

      switch (errno) {
        case EINTR:
          continue;
        case EBADF:
          goto notAlive;
        default:
          NSLog(@"socket select() failed: %s", strerror(errno));
          goto notAlive;
      }
    }

    /* no input is pending, connection is alive */
    if (!FD_ISSET(self->fd, &readMask)) 
      return YES;
  }

  /*
    input is pending: If select() indicates pending input, but ioctl()
    indicates zero bytes of pending input, the connection is broken
  */
  {
#if defined(WIN32) && !defined(__CYGWIN32__)
    u_long len;
#else
    int len;
#endif
    while (ioctl(self->fd, FIONREAD, &len) == -1) {
      if (errno == EINTR) continue;
      goto notAlive;
    }
    if (len > 0) return YES;
  }
  
 notAlive:
  /* valid descriptor, but not alive .. so we close the socket */
#if defined(WIN32) && !defined(__CYGWIN32__)
  closesocket(self->fd);
#else
  close(self->fd);
#endif
  self->fd = NGInvalidSocketDescriptor;
  RELEASE(self->remoteAddress); self->remoteAddress = nil;
  return NO;
}
 
// ******************** NGStream ********************

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  // throws
  //   NGStreamReadErrorException    when the read call failed
  //   NGSocketNotConnectedException when the socket is not connected
  //   NGEndOfStreamException        when the end of the stream is reached
  //   NGWriteOnlyStreamException    when the receive channel was shutdown
  NSException *e = nil;
  
  if (self->fd == NGInvalidSocketDescriptor) {
    [self raise:@"NGSocketException" reason:@"NGActiveSocket is not open"];
    return NGStreamError;
  }
  
  // need to check whether socket is connected
  if (self->remoteAddress == nil) {
    [self raise:@"NGSocketNotConnectedException"
          reason:@"socket is not connected"];
    return NGStreamError;
  }
  
  if (!NGCanReadInStreamMode(self->mode)) {
    [self raise:@"NGWriteOnlyStreamException"];
    return NGStreamError;
  }
  
  if (_len == 0) return 0;

  {
#if defined(WIN32) && !defined(__CYGWIN32__)
    int readResult;

    readResult = recv(self->fd, _buf, _len, 0);
    if (readResult == 0) {
      [self _shutdownDuringOperation];
      [self raise:@"NGSocketShutdownDuringReadException"];
      return NGStreamError;
    }
    else if (readResult < 0) {
      int errorCode = WSAGetLastError();
      
      switch (errorCode) {
        case WSAECONNRESET:
          e = [[NGSocketConnectionResetException alloc] initWithStream:self];
          break;
        case WSAETIMEDOUT:
          e = [[NGSocketTimedOutException alloc] initWithStream:self];
          break;

        case WSAEWOULDBLOCK:
          NSLog(@"WARNING: descriptor would block ..");
          
        default:
          e = [[NGStreamReadErrorException alloc]
                    initWithStream:self errorCode:errorCode];
          break;
      }
      if (e) {
        [self setLastException:e];
        [e release];
        return NGStreamError;
      }
    }
#else /* !WIN32 */
    int readResult;

    NSAssert(_buf,     @"invalid buffer");
    NSAssert1(_len > 0, @"invalid length: %i", _len);
   retry: 
    readResult = NGDescriptorRecv(self->fd, _buf, _len, 0,
                                  (self->receiveTimeout == 0.0)
                                  ? -1 // block until data
                                  : (int)(self->receiveTimeout * 1000.0));
#if DEBUG
    if ((readResult < 0) && (errno == EINVAL)) {
      NSLog(@"%s: invalid argument in NGDescriptorRecv(%i, 0x%p, %i, %i)",
            __PRETTY_FUNCTION__,
            self->fd, _buf, _len, 0,
            (self->receiveTimeout == 0.0)
            ? -1 // block until data
            : (int)(self->receiveTimeout * 1000.0));
    }
#endif
    
    if (readResult == 0) {
      [self _shutdownDuringOperation];
      [self raise:@"NGSocketShutdownDuringReadException"];
      return NGStreamError;
    }
    else if (readResult == -2) {
      [self raise:@"NGSocketTimedOutException"];
      return NGStreamError;
    }
    else if (readResult < 0) {
      int errorCode = errno;

      e = nil;
      switch (errorCode) {
        case 0:
#if DEBUG
          /* this happens with the Oracle7 adaptor !!! */
          NSLog(@"WARNING(%s): readResult<0 (%i), but errno=0 - retry",
                __PRETTY_FUNCTION__, readResult);
#endif
          goto retry;
          break;
          
        case ECONNRESET:
          e = [[NGSocketConnectionResetException alloc] initWithStream:self];
          break;
        case ETIMEDOUT:
          e = [[NGSocketTimedOutException alloc] initWithStream:self];
          break;

        case EWOULDBLOCK:
          NSLog(@"WARNING: descriptor would block ..");
          
        default:
          e = [[NGStreamReadErrorException alloc]
                    initWithStream:self errorCode:errorCode];
          break;
      }
      if (e) {
        [self setLastException:e];
        [e release];
        return NGStreamError;
      }
    }
#endif /* !WIN32 */
    return readResult;
  }
}

#if defined(WIN32) && !defined(__CYGWIN32__)
#warning fix exception handling

- (unsigned)_winWriteBytes:(const void *)_buf count:(unsigned)_len {
  NSException *e = nil;
    int writeResult;

    writeResult = send(self->fd, _buf, _len, 0);
    
    if (writeResult == 0) {
      [self _shutdownDuringOperation];
      [self raise:@"NGSocketShutdownDuringWriteException"];
      return NGStreamError;
    }
    else if (writeResult < 0) {
      int errorCode = WSAGetLastError();
      
      switch (errorCode) {
        case WSAECONNRESET:
          e = [[NGSocketConnectionResetException alloc] initWithStream:self];
          break;
        case WSAETIMEDOUT:
          e = [[NGSocketTimedOutException alloc] initWithStream:self];
          break;

        case WSAEWOULDBLOCK:
          NSLog(@"WARNING: descriptor would block ..");

        default:
          e = [[NGStreamWriteErrorException alloc]
                    initWithStream:self errorCode:errno];
          break;
      }
      if (e) {
        [self setLastException:e];
        [e release];
        return NGStreamError;
      }
    }
    return writeResult;
}

#else 

- (unsigned)_unixWriteBytes:(const void *)_buf count:(unsigned)_len {
   int writeResult;
   int timeOut;
   int retryCount;

   retryCount = 0;
   timeOut = (self->sendTimeout == 0.0)
     ? -1 // block until data
     : (int)(self->sendTimeout * 1000.0);
   
 wretry: 
   writeResult = NGDescriptorSend(self->fd, _buf, _len, MSG_NOSIGNAL, timeOut);
   
   if (writeResult == 0) {
     [self _shutdownDuringOperation];
     [self raise:@"NGSocketShutdownDuringWriteException"];
     return NGStreamError;
   }
   else if (writeResult == -2) {
     [self raise:@"NGSocketTimedOutException"];
     return NGStreamError;
   }
   else if (writeResult < 0) {
     int errorCode = errno;
     
     switch (errorCode) {
       case 0:
#if DEBUG
         /* this happens with the Oracle7 (on SuSE < 7.1??) adaptor !!! */
         NSLog(@"WARNING(%s): writeResult<0 (%i), but errno=0 - retry",
               __PRETTY_FUNCTION__, writeResult);
#endif
         retryCount++;
         if (retryCount > 200000) {
           NSLog(@"WARNING(%s): writeResult<0 (%i), but errno=0 - cancel retry "
                 @"(already tried %i times !!!)",
                 __PRETTY_FUNCTION__, writeResult, retryCount);
           [self _shutdownDuringOperation];
           [self raise:@"NGSocketShutdownDuringWriteException"];
           return NGStreamError;
           break;
         }
         sleep(retryCount);
         goto wretry;
         break;
         
       case ECONNRESET:
         [self raise:@"NGSocketConnectionResetException"];
         return NGStreamError;
       case ETIMEDOUT:
         [self raise:@"NGSocketTimedOutException"];
         return NGStreamError;
         
       case EPIPE:
         [self _shutdownDuringOperation];
         [self raise:@"NGSocketShutdownDuringWriteException"];
         return NGStreamError;
         
       case EWOULDBLOCK:
         NSLog(@"WARNING: descriptor would block ..");
         
       default: {
         NSException *e;
         e = [[NGStreamWriteErrorException alloc]
               initWithStream:self errorCode:errno];
         [self setLastException:e];
         [e release];
         return NGStreamError;
       }
     }
   }
   return writeResult;
}

#endif 
 
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  // throws
  //   NGStreamWriteErrorException   when the write call failed
  //   NGSocketNotConnectedException when the socket is not connected
  //   NGReadOnlyStreamException     when the send channel was shutdown
  
  if (_len == NGStreamError) {
    NSLog(@"ERROR(%s): got NGStreamError passed in as length ...",
          __PRETTY_FUNCTION__);
    return NGStreamError;
  }
#if DEBUG
  if (_len > (1024 * 1024 * 100 /* 100MB */)) {
    NSLog(@"WARNING(%s): got passed in length %uMB (%u bytes, errcode=%u) ...",
          __PRETTY_FUNCTION__, (_len / 1024 / 1024), _len, NGStreamError);
  }
#endif
  
  if (self->fd == NGInvalidSocketDescriptor) {
    [self raise:@"NGSocketException" reason:@"NGActiveSocket is not open"];
    return NGStreamError;
  }
  
  // need to check whether socket is connected
  if (self->remoteAddress == nil) {
    [self raise:@"NGSocketNotConnectedException"
          reason:@"socket is not connected"];
    return NGStreamError;
  }
  
  if (!NGCanWriteInStreamMode(self->mode)) {
    [self raise:@"NGReadOnlyStreamException"];
    return NGStreamError;
  }
  
  //NSLog(@"writeBytes: count:%u", _len);
  
#if defined(WIN32) && !defined(__CYGWIN32__)
  return [self _winWriteBytes:_buf count:_len];
#else
  return [self _unixWriteBytes:_buf count:_len];
#endif
}

- (BOOL)flush {
  return YES;
}
#if 0 
- (BOOL)close {
  return [self shutdown];
}
#endif 

- (NGStreamMode)mode {
  return self->mode;
}

/* methods method which write exactly _len bytes or fail */

- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len {
  volatile int toBeRead;
  int  readResult;
  void *pos;
  unsigned (*readBytes)(id, SEL, void *, unsigned);

  *(&readBytes)  = (void *)[self methodForSelector:@selector(readBytes:count:)];
  *(&toBeRead)   = _len;
  *(&readResult) = 0;
  *(&pos)        = _buf;
  
  while (YES) {
    *(&readResult) =
      readBytes(self, @selector(readBytes:count:), pos, toBeRead);
    
    if (readResult == NGStreamError) {
      NSException *localException;
      NSData *data;
      
      data = [NSData dataWithBytes:_buf length:(_len - toBeRead)];
      
      localException = [[NGEndOfStreamException alloc]
                          initWithStream:self
                          readCount:(_len - toBeRead)
                          safeCount:_len
                          data:data];
      [self setLastException:localException];
      RELEASE(localException);
    }
    
    NSAssert(readResult != 0, @"ERROR: readBytes may not return '0' ..");

    if (readResult == toBeRead) {
      // all bytes were read successfully, return
      break;
    }
    
    if (readResult < 1) {
      [NSException raise:NSInternalInconsistencyException
                   format:@"readBytes:count: returned a value < 1"];
    }

    toBeRead -= readResult;
    pos      += readResult;
  }
  
  return YES;
}

- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len {
  int  toBeWritten = _len;
  int  writeResult;
  void *pos = (void *)_buf;

  /* method cache (THREAD, reentrant) */
  static Class lastClass = Nil;
  static int  (*writeBytes)(id,SEL,const void*,unsigned) = NULL;

  if (lastClass == *(Class *)self) {
    if (writeBytes == NULL)
      writeBytes =
        (void *)[self methodForSelector:@selector(writeBytes:count:)];
  }
  else {
    lastClass = *(Class *)self;
    writeBytes = (void *)[self methodForSelector:@selector(writeBytes:count:)];
  }
  
  while (YES) {
    writeResult =
      (int)writeBytes(self, @selector(writeBytes:count:), pos, toBeWritten);
    
    if (writeResult == NGStreamError) {
      /* remember number of written bytes ??? */
      return NO;
    }
    else if (writeResult == toBeWritten) {
      // all bytes were written successfully, return
      break;
    }

    if (writeResult < 1) {
      [NSException raise:NSInternalInconsistencyException
                   format:@"writeBytes:count: returned a value < 1 in stream %@",
                     self];
      return NO;
    }
    
    toBeWritten -= writeResult;
    pos         += writeResult;
  }
  return YES;
}

- (BOOL)mark {
  return NO;
}
- (BOOL)rewind {
  [self raise:@"NGStreamException" reason:@"stream doesn't support a mark"];
  return NO;
}
- (BOOL)markSupported {
  return NO;
}

// convenience methods

- (int)readByte { // java semantics (-1 returned on EOF)
  int result;
  unsigned char c;
  
  result = [self readBytes:&c count:sizeof(unsigned char)];
  
  if (result != 1) {
    static Class EOFExcClass = Nil;

    if (EOFExcClass == Nil)
      EOFExcClass = [NGEndOfStreamException class];
    
    if ([[self lastException] isKindOfClass:EOFExcClass])
      [self resetLastException];
    
    return -1;
  }
  return (int)c;
}

/* description */

- (NSString *)modeDescription {
  NSString *result = @"<unknown>";
  
  switch ([self mode]) {
    case NGStreamMode_undefined: result = @"<closed>"; break;
    case NGStreamMode_readOnly:  result = @"r";        break;
    case NGStreamMode_writeOnly: result = @"w";        break;
    case NGStreamMode_readWrite: result = @"rw";       break;
    default:
      [[[NGUnknownStreamModeException alloc] initWithStream:self] raise];
      break;
  }
  return result;
}

- (NSString *)description {
  NSMutableString *d = [NSMutableString stringWithCapacity:64];

  [d appendFormat:@"<%@[0x%p]: mode=%@ address=%@",
       NSStringFromClass([self class]), self,
       [self modeDescription], [self localAddress]];

  if ([self isConnected])
    [d appendFormat:@" connectedTo=%@", [self remoteAddress]];

  if ([self sendTimeout] != 0.0) 
    [d appendFormat:@" send-timeout=%4.3fs", [self sendTimeout]];
  if ([self receiveTimeout] != 0.0) 
    [d appendFormat:@" receive-timeout=%4.3fs", [self receiveTimeout]];

  [d appendString:@">"];
  return d;
}

@end /* NGActiveSocket */

@implementation NGActiveSocket(DataMethods)

- (NSData *)readDataOfLength:(unsigned int)_length {
  unsigned readCount;
  char buf[_length];

  if (_length == 0) return [NSData data];

  readCount = [self readBytes:buf count:_length];
  return [NSData dataWithBytes:buf length:readCount];
}

- (NSData *)safeReadDataOfLength:(unsigned int)_length {
  char buf[_length];

  if (_length == 0) return [NSData data];
  [self safeReadBytes:buf count:_length];
  return [NSData dataWithBytes:buf length:_length];
}

- (unsigned int)writeData:(NSData *)_data {
  return [self writeBytes:[_data bytes] count:[_data length]];
}
- (BOOL)safeWriteData:(NSData *)_data {
  return [self safeWriteBytes:[_data bytes] count:[_data length]];
}

@end /* NGActiveSocket(DataMethods) */

#include <NGStreams/NGBufferedStream.h>

@implementation NGBufferedStream(FastSocketForwarders)

- (BOOL)isConnected {
  return [(id)self->source isConnected];
}
- (int)fileDescriptor {
  return [(NSFileHandle *)self->source fileDescriptor];
}

@end /* NGBufferedStream(FastSocketForwarders) */
