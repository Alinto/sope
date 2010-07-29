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

#import <Foundation/Foundation.h>
#import <NGExtensions/NGExtensions.h>
#import <NGExtensions/NSException+misc.h>
#include "NGSocketExceptions.h"

@implementation NGSocketException

- (id)init {
  return [self initWithReason:@"a socket exception occured" socket:nil];
}
- (id)initWithReason:(NSString *)_reason {
  return [self initWithReason:_reason socket:nil];
}

- (id)initWithReason:(NSString *)_reason socket:(id<NGSocket>)_socket {
  self = [super initWithName:NSStringFromClass([self class])
                reason:_reason
                userInfo:nil];
  if (self) {
    self->socket = [_socket retain];
  }
  return self;
}

- (void)dealloc {
  [self->socket release];
  [super dealloc];
}

- (id<NGSocket>)socket {
  return self->socket;
}

@end /* NGSocketException */

@implementation NGCouldNotResolveHostNameException

- (id)init {
  return [self initWithHostName:@"<noname>" reason:nil];
}

- (id)initWithHostName:(NSString *)_name reason:(NSString *)_reason {
  NSString *r;

  r = [[NSString alloc] initWithFormat:@"Could not resolve host %@: %@",
			  _name, _reason ? _reason : (NSString *)@"error"];
  if ((self = [super initWithReason:r socket:nil]) != nil) {
    self->hostName = [_name copy];
  }
  [r release]; r = nil;
  
  return self;
}

- (void)dealloc {
  [self->hostName  release];
  [super dealloc];
}

/* accessors */

- (NSString *)hostName {
  return self->hostName;
}

@end /* NGCouldNotResolveHostNameException */

@implementation NGDidNotFindServiceException

- (id)init {
  return [self initWithServiceName:nil];
}
- (id)initWithServiceName:(NSString *)_service {
  self = [super initWithReason:
                  [NSString stringWithFormat:@"did not find service %@", _service]
                socket:nil];
  if (self) {
    self->serviceName = [_service copy];
  }
  return self;
}

- (void)dealloc {
  [self->serviceName release];
  [super dealloc];
}

- (NSString *)serviceName {
  return self->serviceName;
}

@end /* NGDidNotFindServiceException */

@implementation NGInvalidSocketDomainException

- (id)initWithReason:(NSString *)_reason
  socket:(id<NGSocket>)_socket
  domain:(id<NGSocketDomain>)_domain {

  if ((self = [super initWithReason:_reason socket:nil])) {
    self->domain = [_domain retain];
  }
  return self;
}

- (void)dealloc {
  [self->domain release];
  [super dealloc];
}

- (id<NGSocketDomain>)domain {
  return self->domain;
}

@end /* NGInvalidSocketDomainException */

@implementation NGCouldNotCreateSocketException

- (id)init {
  return [self initWithReason:@"Could not create socket" domain:nil];
}
- (id)initWithReason:(NSString *)_reason domain:(id<NGSocketDomain>)_domain {
  if ((self = [super initWithReason:_reason socket:nil])) {
    self->domain = [_domain retain];
  }
  return self;
}

- (void)dealloc {
  [self->domain release];
  [super dealloc];
}

- (id<NGSocketDomain>)domain {
  return self->domain;
}

@end /* NGCouldNotCreateSocketException */

// ******************** bind ***********************

@implementation NGSocketBindException
@end /* NGSocketBindException */

@implementation NGSocketAlreadyBoundException

- (id)init {
  return [self initWithReason:@"Socket is already bound"];
}

@end /* NGSocketAlreadyBoundException */

@implementation NGCouldNotBindSocketException

- (id)init {
  return [self initWithReason:@"could not bind socket" socket:nil address:nil];
}

- (id)initWithReason:(NSString *)_reason
  socket:(id<NGSocket>)_socket
  address:(id<NGSocketAddress>)_address {

  if ((self = [super initWithReason:_reason socket:_socket])) {
    self->address = [_address retain];
  }
  return self;
}

- (void)dealloc {
  [self->address release];
  [super dealloc];
}

- (id<NGSocketAddress>)address {
  return self->address;
}

@end /* NGCouldNotBindSocketException */

// ******************** connect ********************

@implementation NGSocketConnectException
@end /* NGSocketConnectException */

@implementation NGSocketNotConnectedException

- (id)init {
  return [self initWithReason:@"Socket is not connected"];
}

@end /* NGSocketNotConnectedException */

@implementation NGSocketAlreadyConnectedException

- (id)init {
  return [self initWithReason:@"Socket is already connected"];
}

@end /* NGSocketAlreadyConnectedException */

@implementation NGCouldNotConnectException

- (id)init {
  return [self initWithReason:@"could not connect socket" socket:nil address:nil];
}

- (id)initWithReason:(NSString *)_reason
  socket:(id<NGActiveSocket>)_socket
  address:(id<NGSocketAddress>)_address {

  if ((self = [super initWithReason:_reason socket:_socket])) {
    self->address = [_address retain];
  }
  return self;
}

- (void)dealloc {
  [self->address release];
  [super dealloc];
}

- (id<NGSocketAddress>)address {
  return self->address;
}

@end /* NGCouldNotConnectException */

// ******************** listen ********************

@implementation NGSocketIsAlreadyListeningException

- (id)init {
  return [self initWithReason:@"Socket is already listening"];
}

@end /* NGSocketIsAlreadyListeningException */

@implementation NGCouldNotListenException
@end /* NGCouldNotListenException */

// ******************** accept ********************

@implementation NGCouldNotAcceptException
@end /* NGCouldNotAcceptException */

// ******************** options ********************

@implementation NGSocketOptionException

- (id)init {
  return [self initWithReason:@"Could not get/set socket option" option:-1 level:-1];
}
- (id)initWithReason:(NSString *)_reason option:(int)_option level:(int)_level {
  if ((self = [super initWithReason:_reason])) {
    option = _option;
    level  = _level;
  }
  return self;
}

- (int)option {
  return option;
}
- (int)level {
  return level;
}

@end /* NGSocketOptionException */

@implementation NGCouldNotSetSocketOptionException
@end /* NGCouldNotSetSocketOptionException */

@implementation NGCouldNotGetSocketOptionException
@end /* NGCouldNotGetSocketOptionException */

// ******************** socket closed **************

@implementation NGSocketShutdownException

- (id)init {
  return [self initWithStream:nil reason:@"the socket was shutdown"];
}
- (id)initWithReason:(NSString *)_reason {
  return [self initWithStream:nil reason:_reason];
}
- (id)initWithReason:(NSString *)_reason socket:(id<NGActiveSocket>)_socket {
  return [self initWithStream:_socket reason:_reason];
}

- (id)initWithSocket:(id<NGActiveSocket>)_socket {
  return [self initWithStream:_socket reason:@"the socket was shutdown"];
}

/* accessors */

- (id<NGActiveSocket>)socket {
  return [self->streamPointer nonretainedObjectValue];
}

@end /* NGSocketShutdownException */

@implementation NGSocketShutdownDuringReadException
@end

@implementation NGSocketShutdownDuringWriteException
@end

@implementation NGSocketTimedOutException
@end

@implementation NGSocketConnectionResetException
@end
