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

#ifndef __NGNet_NGSocketExceptions_H__
#define __NGNet_NGSocketExceptions_H__

#import <Foundation/NSException.h>
#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGSocketProtocols.h>

/*
  Exceptions:

    NGIOException
      NGSocketException
        NGSocketBindException
          NGSocketAlreadyBoundException
          NGCouldNotBindSocketException
        NGSocketConnectionException
          NGSocketNotConnectedException
          NGSocketAlreadyConnectedException
          NGCouldNotConnectException
        NGSocketOptionException
          NGCouldNotSetSocketOptionException
          NGCouldNotGetSocketOptionException
        NGCouldNotResolveHostNameException
        NGDidNotFindServiceException
        NGSocketIsAlreadyListeningException
        NGCouldNotListenException
        NGCouldNotAcceptException
        NGInvalidSocketDomainException
        NGCouldNotCreateSocketException
      NGStreamException
        NGEndOfStreamException
          NGSocketShutdownException
            NGSocketShutdownDuringReadException
            NGSocketShutdownDuringWriteException
            NGSocketConnectionResetException
            NGSocketTimedOutException
*/

@interface NGSocketException : NGIOException
{
@protected
  id<NGSocket> socket;
}

- (id)init;
- (id)initWithReason:(NSString *)_reason;
- (id)initWithReason:(NSString *)_reason socket:(id<NGSocket>)_socket;

- (id<NGSocket>)socket;

@end

@interface NGCouldNotResolveHostNameException : NGSocketException
{
@protected
  NSString *hostName;
}

- (id)initWithHostName:(NSString *)_name reason:(NSString *)_reason;

- (NSString *)hostName;

@end

@interface NGDidNotFindServiceException : NGSocketException
{
@protected
  NSString *serviceName;
}

- (id)init;
- (id)initWithServiceName:(NSString *)_service;

- (NSString *)serviceName;

@end

@interface NGInvalidSocketDomainException : NGSocketException
{
@protected
  id<NGSocketDomain> domain;
}

- (id)initWithReason:(NSString *)_reason
  socket:(id<NGSocket>)_socket domain:(id<NGSocketDomain>)_domain;

@end

@interface NGCouldNotCreateSocketException : NGSocketException
{
@protected
  id<NGSocketDomain> domain;
}

- (id)init;
- (id)initWithReason:(NSString *)_reason domain:(id<NGSocketDomain>)_domain;

@end

// ******************** bind ***********************

@interface NGSocketBindException : NGSocketException
@end

@interface NGSocketAlreadyBoundException : NGSocketBindException
@end

@interface NGCouldNotBindSocketException : NGSocketBindException
{
@protected
  id<NGSocketAddress> address;
}

- (id)initWithReason:(NSString *)_reason
  socket:(id<NGSocket>)_socket address:(id<NGSocketAddress>)address;

- (id<NGSocketAddress>)address;

@end

// ******************** connect ********************

@interface NGSocketConnectException : NGSocketException
@end

@interface NGSocketNotConnectedException : NGSocketConnectException
@end

@interface NGSocketAlreadyConnectedException : NGSocketConnectException
@end

@interface NGCouldNotConnectException : NGSocketConnectException
{
@protected
  id<NGSocketAddress> address;
}

- (id)initWithReason:(NSString *)_reason
  socket:(id<NGActiveSocket>)_socket
  address:(id<NGSocketAddress>)address;

- (id<NGSocketAddress>)address;

@end

// ******************** listen ********************

@interface NGSocketIsAlreadyListeningException : NGSocketException
@end

@interface NGCouldNotListenException : NGSocketException
@end

// ******************** accept ********************

@interface NGCouldNotAcceptException : NGSocketException
@end

// ******************** options ********************

@interface NGSocketOptionException : NGSocketException
{
@protected
  int option;
  int level;
}

- (id)init;
- (id)initWithReason:(NSString *)_reason option:(int)_option level:(int)_level;

@end

@interface NGCouldNotSetSocketOptionException : NGSocketOptionException
@end

@interface NGCouldNotGetSocketOptionException : NGSocketOptionException
@end

// ******************** socket closed **************

@interface NGSocketShutdownException : NGEndOfStreamException

- (id)initWithReason:(NSString *)_reason;
- (id)initWithReason:(NSString *)_reason socket:(id<NGActiveSocket>)_socket;
- (id)initWithSocket:(id<NGActiveSocket>)_socket;

/* Note: this only returns a valid ptr, if the socket is still retained ! */
- (id<NGActiveSocket>)socket;

@end

@interface NGSocketShutdownDuringReadException : NGSocketShutdownException
@end

@interface NGSocketShutdownDuringWriteException : NGSocketShutdownException
@end

@interface NGSocketTimedOutException : NGSocketShutdownException
@end

@interface NGSocketConnectionResetException : NGSocketShutdownException
@end

#endif /* __NGNet_NGSocketExceptions_H__ */
