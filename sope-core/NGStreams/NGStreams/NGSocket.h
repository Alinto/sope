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

#ifndef __NGNet_NGSocket_H__
#define __NGNet_NGSocket_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGSocketProtocols.h>

#if defined(WIN32)
#  include <winsock.h>
#endif

@class NSFileHandle, NSException;

/*
  Represents the sockets accessible through the standard Unix sockets library.
  The socket class itself is abstract and has two concrete subclasses,
  NGActiveSocket and NGPassiveSocket. The terminology may be confusing
  at first, but I choose to use these instead of Client/ServerSocket
  because the NGPassiveSocket accept method returns a socket which isn't
  one of these. It's an active socket which is already connected.
  NGActiveSocket represents a connection while NGPassiveSocket only accepts
  connections (it can't be read or written).

  Each socket has a local address. The socket can be bound to an address
  by using the bind() call or the address can be assigned by the operating
  system kernel.
  Passive sockets are normally bound to a well-known port (or service),
  active sockets receive in most cases their address from the kernel.

  fd is the file descriptor gained through the socket() call. closeOnFree
  specifies whether the socket is closed when the memory for the
  socket object is reclaimed.

  Note that the creation of the actual socket has to wait until it is
  bound or a connect or listen call has been initiated. This is because
  the socket() call needs the socket-domain, which is encapsulated in the
  NGSocketAddress objects.
  Until the socket is created the fd variable contains the value
  NGInvalidSocketDescriptor.
*/

#if defined(WIN32)
#  define NGInvalidSocketDescriptor INVALID_SOCKET
#else
#  define NGInvalidSocketDescriptor ((int)-1)
#endif

@interface NGSocket : NSObject < NGSocket >
{
@protected
#if defined(WIN32)
  SOCKET              fd;
#else
  int                 fd;           // socket descriptor
#endif
  id<NGSocketDomain>  domain;
  id<NGSocketAddress> localAddress;
  NSFileHandle        *fileHandle;  // not retained !

  struct {
    int closeOnFree:1; // close socket on collect/dealloc ?
    int isBound:1;     // was a bind issued (either by the kernel or explicitly)
  } flags;
  
  NSException *lastException;
}

+ (id)socketInDomain:(id<NGSocketDomain>)_domain;
- (id)initWithDomain:(id<NGSocketDomain>)_domain; // designated initializer

// ************************* create a socket *****************

- (BOOL)primaryCreateSocket;
- (BOOL)close;

// ************************* bind a socket *******************

// throws
//   NGSocketAlreadyBoundException    if the socket is already bound
- (BOOL)bindToAddress:(id<NGSocketAddress>)_address;

// throws
//   NGSocketAlreadyBoundException    if the socket is already bound
- (BOOL)kernelBoundAddress;

// ************************* accessors ***********************

- (id<NGSocketAddress>)localAddress;
- (BOOL)isBound;

- (void)setLastException:(NSException *)_exception;
- (NSException *)lastException;
- (void)resetLastException;

- (int)socketType;       // abstract
- (id<NGSocketDomain>)domain;

- (NSFileHandle *)fileHandle;
#if defined(WIN32)
- (SOCKET)fileDescriptor;
#else
- (int)fileDescriptor;
- (void)setFileDescriptor: (int) theFd;
#endif

// ************************* options *************************
//
//   set methods throw NGCouldNotSetSocketOptionException
//   get methods throw NGCouldNotGetSocketOptionException

- (void)setDebug:(BOOL)_flag;
- (void)setReuseAddress:(BOOL)_flag;
- (void)setKeepAlive:(BOOL)_flag;
- (void)setDontRoute:(BOOL)_flag;
- (BOOL)doesDebug;
- (BOOL)doesReuseAddress;
- (BOOL)doesKeepAlive;
- (BOOL)doesNotRoute;

- (void)setSendBufferSize:(int)_size;
- (void)setReceiveBufferSize:(int)_size;
- (int)sendBufferSize;
- (int)receiveBufferSize;

@end

#if defined(WIN32)

// Windows Descriptor Functions

// events
#  ifndef POLLIN
#    define POLLRDNORM 1
#    define POLLIN     POLLRDNORM
#    define POLLWRNORM 2
#    define POLLOUT    POLLWRNORM
#    define POLLERR    4
#    define POLLHUP    4
#  endif

/*
  Polls a descriptor. Returns 1 if events occurred, 0 if a timeout occured
  and -1 if an error other than EINTR or EAGAIN occured.
*/
int NGPollDescriptor(SOCKET _fd, short _events, int _timeout);

/*
  Reading and writing with non-blocking IO support.
  The functions return
    -1  on error, with errno set to either recv's or poll's errno
    0   on the end of file condition
    -2  if the operation timed out

  Enable login topic 'nonblock' to find out about timeouts.
*/
int NGDescriptorRecv(SOCKET _fd, char *_buf, int _len, int _flags, int _timeout);
int NGDescriptorSend(SOCKET _fd, const char *_buf, int _len, int _flags, int _timeout);

#endif /* WIN32 */

#endif /* __NGNet_NGSocket_H__ */
