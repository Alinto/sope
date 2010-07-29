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

#ifndef __NGNet_NGPassiveSocket_H__
#define __NGNet_NGPassiveSocket_H__

#import <Foundation/NSLock.h>
#include <NGStreams/NGSocket.h>
#include <NGStreams/NGSocketProtocols.h>

/*
  Represents a STREAM server socket based on the standard Unix sockets library.

  A passive socket has exactly one address, the address the socket is bound to.
  If you do not bind the socket, the address is determined after the listen()
  call was executed through the getsockname() call.

  Note that if the socket is bound it's still an active socket in the
  system's view, it becomes an passive one when the listen call is executed.

  NOTE: Currently the passive _must_ be bound. This is because during the
        creation of the socket the domain is needed. The domain is encapsulated
        in the socket-address.
        Therefore the method of letting the kernel determine a socket address,
        as described above, currently does not work.
*/

@interface NGPassiveSocket : NGSocket < NGPassiveSocket >
{
@protected
  id<NSObject,NSLocking> acceptLock; // prevents file-locking
  int backlogSize;
}

+ (id)socketBoundToAddress:(id<NGSocketAddress>)_address;

/* accessors */

- (BOOL)isListening;
- (BOOL)isOpen;

/* operations */

// throws
//   NGSocketIsAlreadyListeningException  when the socket is in the listen state
//   NGCouldNotListenException            when the listen call failed
- (BOOL)listenWithBacklog:(int)_backlogSize;

// accept blocks when multiple threads try to accept (using acceptLock)
// throws
//   NGCouldNotAcceptException  when the socket is not listening
//   NGCouldNotAcceptException  when the accept call failed
- (id<NGActiveSocket>)accept;

@end

#endif /* __NGNet_NGPassiveSocket_H__ */
