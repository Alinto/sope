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

#include <NGStreams/NGConcreteStreamFileHandle.h>
#include "NGSocketExceptions.h"
#include "NGSocket.h"
#include "NGSocket+private.h"
#include "NGInternetSocketDomain.h"

#include "config.h"
#if defined(__APPLE__)
#  include <sys/types.h>
#  include <sys/socket.h>
#endif

#if defined(HAVE_UNISTD_H) || defined(__APPLE__)
#  include <unistd.h>
#endif

#include "common.h"

@interface _NGConcreteSocketFileHandle : NGConcreteStreamFileHandle
{
}

- (id)initWithSocket:(id<NGSocket>)_socket;

@end

@interface NSObject(WildcardAddresses)
- (BOOL)isWildcardAddress;
@end

#ifdef __s390__
#  define SockAddrLenType socklen_t
#elif __APPLE__
#  define SockAddrLenType unsigned int
#else
#  define SockAddrLenType socklen_t
#endif

@implementation NGSocket

#if defined(WIN32) && !defined(__CYGWIN32__)

static BOOL    isInitialized = NO;
static WSADATA wsaData;

+ (int)version {
  return 2;
}

+ (void)initialize {
  if (!isInitialized) {
    isInitialized = YES;

    if (WSAStartup(MAKEWORD(1, 1), &wsaData) != 0)
      NSLog(@"WARNING: Could not start Windows sockets !");

    NSLog(@"WinSock version %i.%i.",
          LOBYTE(wsaData.wVersion), HIBYTE(wsaData.wVersion));
  }
}

static void _killWinSock(void) __attribute__((destructor));
static void _killWinSock(void) {
  fprintf(stderr, "killing Windows sockets ..\n");
  if (isInitialized) {
    WSACleanup();
    isInitialized = NO;
  }
}

#endif /* WIN32 */

+ (id)socketInDomain:(id<NGSocketDomain>)_domain {
  return [[[self alloc] initWithDomain:_domain] autorelease];
}

- (id)init {
  return [self initWithDomain:[NGInternetSocketDomain domain]];
}

#if defined(WIN32) && !defined(__CYGWIN32__)
- (id)_initWithDomain:(id<NGSocketDomain>)_domain descriptor:(SOCKET)_fd {
#else
- (id)_initWithDomain:(id<NGSocketDomain>)_domain descriptor:(int)_fd {
#endif
  if ((self = [super init])) {
    self->fd                = _fd;
    self->flags.closeOnFree = YES;
    self->flags.isBound     = (_fd == NGInvalidSocketDescriptor) ? NO : YES;
    self->domain            = [_domain retain];

    if (_fd == NGInvalidSocketDescriptor)
      [self primaryCreateSocket];
  }
  return self;
}
- (id)initWithDomain:(id<NGSocketDomain>)_domain {
  return [self _initWithDomain:_domain descriptor:NGInvalidSocketDescriptor];
}

- (void)gcFinalize {
  if (self->flags.closeOnFree)
    [self close];
  else
    NSLog(@"WARNING: socket was not 'closeOnFree' !");
}

- (void)dealloc {
  [self gcFinalize];

  [self->lastException release];
  [self->localAddress  release];
  [self->domain  release];
  self->fileHandle = nil;
  [super dealloc];
}

/* creation */

- (BOOL)primaryCreateSocket {
  // throws
  //   NGCouldNotCreateSocketException  if the socket creation failed
  
  fd = socket([domain socketDomain], [self socketType], [domain protocol]);

#if defined(WIN32) && !defined(__CYGWIN32__)
  if (fd == SOCKET_ERROR) { // error
    int e = WSAGetLastError();
    NSString *reason = nil;
    
    switch (e) {
      case WSAEACCES:
        reason = @"Not allowed to create socket of this type";
        break;
      case WSAEMFILE:
        reason = @"Could not create socket: descriptor table is full";
        break;
      case WSAEPROTONOSUPPORT:
        reason = @"Could not create socket: The protocol type or the specified "
                 @"protocol  is  not  supported within this domain";
        break;
      default:
        reason = [NSString stringWithFormat:@"Could not create socket: %s",
                             strerror(e)];
        break;
    }
#else
  if (fd == -1) { // error
    int      e       = errno;
    NSString *reason = nil;
    
    switch (e) {
      case EACCES:
        reason = @"Not allowed to create socket of this type";
        break;
      case EMFILE:
        reason = @"Could not create socket: descriptor table is full";
        break;
      case ENOMEM:
        reason = @"Could not create socket: Insufficient user memory available";
        break;
      case EPROTONOSUPPORT:
        reason = @"Could not create socket: The protocol type or the specified "
                 @"protocol  is  not  supported within this domain";
        break;
      default:
        reason = [NSString stringWithFormat:@"Could not create socket: %s",
                             strerror(e)];
        break;
    }
#endif

    [[[NGCouldNotCreateSocketException alloc]
              initWithReason:reason domain:domain] raise];
    return NO;
  }
  return YES;
}

- (BOOL)close {
  if (self->fd != NGInvalidSocketDescriptor) {
#if DEBUG && 0
    NSLog(@"%@: closing socket fd %i", self, self->fd);
#endif
#if defined(WIN32) && !defined(__CYGWIN32__)
    closesocket(self->fd);
#else
    close(self->fd);
#endif
    self->fd = NGInvalidSocketDescriptor;

    if (self->flags.isBound) {
      self->flags.isBound = NO;
      [[self domain] cleanupAddress:self->localAddress
                     afterCloseOfSocket:self];
    }
    else
      self->flags.isBound = NO;
  }
  return YES;
}

/* operations */

- (void)setLastException:(NSException *)_exception {
  /* NOTE: watch out for cycles !!! */
  // THREAD
  ASSIGN(self->lastException, _exception);
}
- (NSException *)lastException {
  // THREAD
  return self->lastException;
}
- (void)resetLastException {
  // THREAD
  ASSIGN(self->lastException,(id)nil);
}
 
- (BOOL)primaryBindToAddress:(id<NGSocketAddress>)_address {
  // throws
  //   NGCouldNotBindSocketException    if the bind failed

  [[self domain] prepareAddress:_address
                 forBindWithSocket:self];

  if (bind(fd,
           (struct sockaddr *)[_address internalAddressRepresentation],
           [_address addressRepresentationSize]) != 0) {
    NSString *reason = nil;
#if defined(WIN32) && !defined(__CYGWIN32__)
    int errorCode = WSAGetLastError();
#else    
    int errorCode = errno;
#endif

    switch (errorCode) {
      default:
        reason = [NSString stringWithCString:strerror(errorCode)];
        break;
    }

    reason = [NSString stringWithFormat:@"Could not bind to address %@: %@",
                         _address, reason];
    
    [[[NGCouldNotBindSocketException alloc]
              initWithReason:reason socket:self address:_address] raise];
    return NO;
  }

  /* bind was successful */
  
  ASSIGN(self->localAddress, _address);
  self->flags.isBound = YES;
  return YES;
}

- (BOOL)bindToAddress:(id<NGSocketAddress>)_address {
  // throws
  //   NGSocketAlreadyBoundException    if the socket is already bound
  //   NGCouldNotCreateSocketException  if the socket creation failed
  //   NGCouldNotBindSocketException    if the bind failed

  // check whether socket is already bound (either manually or by the kernel)
  if (flags.isBound) {
    [[[NGSocketAlreadyBoundException alloc]
              initWithReason:@"socket is already bound." socket:self] raise];
  }

  if (_address == nil) {
    /* let kernel bind address */
    return [self kernelBoundAddress];
  }
  
  // perform bind
  if (![self primaryBindToAddress:_address])
    return NO;
  
  /* check for wildcard port */
  
  if ([_address respondsToSelector:@selector(isWildcardAddress)]) {
    if ([(id)_address isWildcardAddress]) {
      SockAddrLenType len = [[_address domain] addressRepresentationSize];
      char data[len]; // struct sockaddr
      
      if (getsockname(fd, (void *)&data, &len) == 0) { // function is MT-safe
        id<NGSocketAddress> boundAddr;
        
        boundAddr = [[_address domain]
                               addressWithRepresentation:&(data[0])
                               size:len];
#if 0
        NSLog(@"got sock name (addr-len=%d, %s, %d) %@ ..",
              len,
              inet_ntoa( (((struct sockaddr_in *)(&data[0]))->sin_addr)),
              ntohs(((struct sockaddr_in *)(&data[0]))->sin_port),
              boundAddr);
#endif   
        ASSIGN(self->localAddress, boundAddr);
      }
      else {
        // could not get local socket name, THROW
        NSLog(@"ERROR: couldn't resolve wildcard address %@", _address);
      }
    }
  }
  return YES;
}

- (BOOL)kernelBoundAddress {
  SockAddrLenType len = [[self domain] addressRepresentationSize];
  char   data[len];
  
  // check whether socket is already bound (either manually or by the kernel)
  if (flags.isBound) {
    [[[NGSocketAlreadyBoundException alloc]
              initWithReason:@"socket is already bound." socket:self] raise];
    return NO;
  }
  
#if 0
  NSLog(@"socket: kernel bound address of %i in domain %@",
        self->fd, [self domain]);
#endif
  
  if (getsockname(self->fd, (void *)&data, &len) != 0) { // function is MT-safe
    // could not get local socket name, THROW
    [[[NGSocketException alloc]
         initWithReason:@"could not get local socket name" socket:self] raise];
    return NO;
  }

  if (self->localAddress) { // release old address
    [self->localAddress release];
    self->localAddress = nil;
  }
  self->localAddress = [[self domain] addressWithRepresentation:(void *)data
                                      size:len];
  self->localAddress  = [self->localAddress retain];
  self->flags.isBound = YES;
  return YES;
}

/* accessors */

- (id<NGSocketAddress>)localAddress {
  return self->localAddress;
}

- (BOOL)isBound {
  return self->flags.isBound;
}

- (int)socketType {
  [self subclassResponsibility:_cmd];
  return -1;
}

- (id<NGSocketDomain>)domain {
  return self->domain;
}

#if defined(WIN32) && !defined(__CYGWIN32__)
- (SOCKET)fileDescriptor {
#else 
- (int)fileDescriptor {
#endif
  return self->fd;
}

- (void)setFileDescriptor: (int) theFd
{
  self->fd = theFd;
}

- (void)resetFileHandle { // called by the NSFileHandle on dealloc
  self->fileHandle = nil;
}
- (NSFileHandle *)fileHandle {
  /* the filehandle will reset itself from the stream when being deallocated */
  if (self->fileHandle == nil) {
    self->fileHandle =
      [(_NGConcreteSocketFileHandle *)[_NGConcreteSocketFileHandle alloc]
                                          initWithSocket:self];
  }
  return [self->fileHandle autorelease];
}

/* options */

- (void)setOption:(int)_option level:(int)_level value:(void *)_value len:(int)_len {
  if (setsockopt(fd, _level, _option, _value, _len) != 0) {
    NSString *reason = nil;
#if defined(WIN32) && !defined(__CYGWIN32__)
    int e = WSAGetLastError();

   switch (e) {
     case WSAEBADF:
       reason = @"Could not set socket option, invalid file descriptor";
       break;
     case WSAEINVAL:
       reason =
         @"Could not set socket option, option is invalid or socket has been"
         @"shut down";
       break;
     case WSAENOPROTOOPT:
       reason = @"Could not set socket option, option is not supported by protocol";
       break;
     case WSAENOTSOCK:
       reason = @"Could not set socket option, descriptor isn't a socket";
       break;
     default:
       reason = [NSString stringWithFormat:@"Could not set socket option: %s",
                            strerror(e)];
       break;
   }
#else
    int e = errno;
    
    switch (e) {
      case EBADF:
        reason = @"Could not set socket option, invalid file descriptor";
        break;
      case EINVAL:
        reason =
          @"Could not set socket option, option is invalid or socket has been"
          @"shut down";
        break;
      case ENOPROTOOPT:
        reason = @"Could not set socket option, option is not supported by protocol";
        break;
      case ENOTSOCK:
        reason = @"Could not set socket option, descriptor isn't a socket";
        break;
      default:
        reason = [NSString stringWithFormat:@"Could not set socket option: %s",
                             strerror(e)];
        break;
    }
#endif
    [[[NGCouldNotSetSocketOptionException alloc]
         initWithReason:reason option:_option level:_level] raise];
  }
}
- (void)setOption:(int)_option value:(void *)_value len:(int)_len {
  [self setOption:_option level:SOL_SOCKET value:_value len:_len];
}

- (void)getOption:(int)_option level:(int)_level value:(void *)_value
  len:(int *)_len
{
  int rc;
  socklen_t tlen;
  
  rc = getsockopt(fd, _level, _option, _value, &tlen);
  if (_len) *_len = tlen;
  if (rc != 0) {
    NSString *reason = nil;
#if defined(WIN32) && !defined(__CYGWIN32__)
    int e = WSAGetLastError();
    
    switch (e) {
      case WSAEBADF:
        reason = @"Could not get socket option, invalid file descriptor";
        break;
      case WSAEINVAL:
        reason =
          @"Could not get socket option, option is invalid at the specified level";
        break;
      case WSAENOPROTOOPT:
        reason = @"Could not get socket option, option is not supported by protocol";
        break;
      case WSAENOTSOCK:
        reason = @"Could not get socket option, descriptor isn't a socket";
        break;
      case WSAEOPNOTSUPP:
        reason =
          @"Could not get socket option, operation is not supported by protocol";
        break;
      default:
        reason = [NSString stringWithFormat:@"Could not get socket option: %s",
                             strerror(e)];
        break;
    }
#else
    int e = errno;
    
    switch (e) {
      case EBADF:
        reason = @"Could not get socket option, invalid file descriptor";
        break;
      case EINVAL:
        reason =
          @"Could not get socket option, option is invalid at the specified level";
        break;
      case ENOPROTOOPT:
        reason = @"Could not get socket option, option is not supported by protocol";
        break;
      case ENOTSOCK:
        reason = @"Could not get socket option, descriptor isn't a socket";
        break;
      case EOPNOTSUPP:
        reason =
          @"Could not get socket option, operation is not supported by protocol";
        break;
      default:
        reason = [NSString stringWithFormat:@"Could not get socket option: %s",
                             strerror(e)];
        break;
    }
#endif
    [[[NGCouldNotGetSocketOptionException alloc]
         initWithReason:reason option:_option level:_level] raise];
  }
}
- (void)getOption:(int)_option value:(void *)_value len:(int *)_len {
  [self getOption:_option level:SOL_SOCKET value:_value len:_len];
}

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

- (void)setDebug:(BOOL)_flag {
  setBoolOption(self, SO_DEBUG, _flag);
}
- (BOOL)doesDebug {
  return getBoolOption(self, SO_DEBUG);
}

- (void)setReuseAddress:(BOOL)_flag {
  setBoolOption(self, SO_REUSEADDR, _flag);
}
- (BOOL)doesReuseAddress {
  return getBoolOption(self, SO_REUSEADDR);
}

- (void)setKeepAlive:(BOOL)_flag {
  setBoolOption(self, SO_KEEPALIVE, _flag);
}
- (BOOL)doesKeepAlive {
  return getBoolOption(self, SO_KEEPALIVE);
}

- (void)setDontRoute:(BOOL)_flag {
  setBoolOption(self, SO_DONTROUTE, _flag);
}
- (BOOL)doesNotRoute {
  return getBoolOption(self, SO_DONTROUTE);
}

- (void)setSendBufferSize:(int)_size {
  [self setOption:SO_SNDBUF level:SOL_SOCKET value:&_size len:sizeof(_size)];
}
- (int)sendBufferSize {
  int size, len;
  [self getOption:SO_SNDBUF level:SOL_SOCKET value:&size len:&len];
  return size;
}

- (void)setReceiveBufferSize:(int)_size {
  [self setOption:SO_RCVBUF level:SOL_SOCKET value:&_size len:sizeof(_size)];
}
- (int)receiveBufferSize {
  int size, len;
  [self getOption:SO_RCVBUF level:SOL_SOCKET value:&size len:&len];
  return size;
}

- (int)getSocketError {
  int error, len;
  [self getOption:SO_ERROR level:SOL_SOCKET value:&error len:&len];
  return error;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p]: fd=%i type=%i bound=%@ domain=%@>",
                     NSStringFromClass([self class]), self,
                     [self fileDescriptor],
                     [self socketType],
                     [self localAddress] ? [self localAddress] : (id)@"no",
                     [self domain]
                   ];
}

@end /* NGSocket */


@implementation _NGConcreteSocketFileHandle

- (id)initWithSocket:(id<NGSocket>)_socket {
  return [super initWithStream:(id<NGStream>)_socket];
}

// accessors

- (int)fileDescriptor {
  return [(NGSocket *)stream fileDescriptor];
}

@end /* _NGConcreteSocketFileHandle */

#if defined(WIN32) && !defined(__CYGWIN32__)

// Windows Descriptor functions

// ******************** Poll *********************

int NGPollDescriptor(SOCKET _fd, short _events, int _timeout) {
  struct timeval timeout;
  fd_set rSet;
  fd_set wSet;
  fd_set eSet;
  int    result;
  FD_ZERO(&rSet);
  FD_ZERO(&wSet);
  FD_ZERO(&eSet);

  if (_events & POLLIN)  FD_SET(_fd, &rSet);
  if (_events & POLLOUT) FD_SET(_fd, &wSet);
  if (_events & POLLERR) FD_SET(_fd, &eSet);

  timeout.tv_sec  = _timeout / 1000;
  timeout.tv_usec = _timeout * 1000 - timeout.tv_sec * 1000000;

  do {
    result = select(FD_SETSIZE, &rSet, &wSet, &eSet, &timeout);
    if (result == -1) { // error
      int e = WSAGetLastError();
      if (e != WSAEINTR)
        // only retry of interrupted or repeatable
        break;
    }
  }
  while (result == -1);

  return (result < 0) ? -1 : result;
}

// ******************** Flags ********************

#if 0 
int NGGetDescriptorFlags(int _fd) {
  int val;

  val = fcntl(_fd, F_GETFL, 0);
  if (val < 0)
    [NGIOException raiseWithReason:@"could not get descriptor flags"];
  return val;
}
void NGSetDescriptorFlags(int _fd, int _flags) {
  if (fcntl(_fd, F_SETFL, _flags) == -1)
    [NGIOException raiseWithReason:@"could not set descriptor flags"];
}

void NGAddDescriptorFlag (int _fd, int _flag) {
  int val = NGGetDescriptorFlags(_fd);
  NGSetDescriptorFlags(_fd, val | _flag);
}
#endif 

// ******************** NonBlocking IO ************

int NGDescriptorRecv(SOCKET _fd, char *_buf, int _len, int _flags, int _timeout) {
  int errorCode;
  int result;

  result = recv(_fd, _buf, _len, _flags);
  if (result == 0) return 0; // EOF

  errorCode = errno;

  if ((result == -1) && (errorCode == WSAEWOULDBLOCK)) { // retry
#if 0
    struct pollfd pfd;
    pfd.fd      = _fd;
    pfd.events  = POLLRDNORM;
    pfd.revents = 0;

    do {
      if ((result = poll(&pfd, 1, _timeout)) < 0) {
        errorCode = errno;

        // retry if interrupted
        if ((errorCode != EINTR) && (errorCode != EAGAIN)) 
          break;
      }
    }
    while (result < 0);
#endif
    result = 1;

    if (result == 1) { // data waiting, try to read
      result = recv(_fd, _buf, _len, _flags);
      if (result == 0)
        return 0; // EOF
      else if (result == -1) {
        errorCode = errno;

        if (errorCode == WSAEWOULDBLOCK)
          NSLog(@"WARNING: would block although descriptor was polled ..");
      }
    }
    else if (result == 0) {
      result = -2;
    }
    else
      result = -1;
  }

  return result;
}

int NGDescriptorSend(SOCKET _fd, const char *_buf, int _len, int _flags,
                     int _timeout) {
  int errorCode;
  int result;

  result = send(_fd, _buf, _len, _flags);
  if (result == 0) return 0; // EOF

  errorCode = errno;

  if ((result == -1) && (errorCode == WSAEWOULDBLOCK)) { // retry
#if 0
    struct pollfd pfd;
    pfd.fd      = _fd;
    pfd.events  = POLLWRNORM;
    pfd.revents = 0;

    do {
      if ((result = poll(&pfd, 1, _timeout)) < 0) {
        errorCode = errno;

        if (errorCode != WSAEINTR) // retry only if interrupted
          break;
      }
    }
    while (result < 0);
#endif
    result = 1; // block ..

    if (result == 1) { // data waiting, try to read
      result = send(_fd, _buf, _len, _flags);
      if (result == 0) return 0; // EOF
    }
    else if (result == 0) {
#if 0
      NSLog(@"nonblock: send on %i timed out after %i milliseconds ..",
             _fd, _timeout);
#endif
      result = -2;
    }
    else
      result = -1;
  }

  return result;
}

#endif /* WIN32 */
