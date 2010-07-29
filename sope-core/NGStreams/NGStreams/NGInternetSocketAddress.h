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

#ifndef __NGNet_NGInternetSocketAddress_H__
#define __NGNet_NGInternetSocketAddress_H__

#include <NGStreams/NGSocketProtocols.h>
#include <NGStreams/NGActiveSocket.h>

/*
  Represents an Internet socket address (AF_INET).
  
  Socket addresses are immutable. -copy therefore returns a retained self.

  The host arguments are id because they are allowed to be either NSString
  or NSHost objects (although NSString's are preferred). If the host is nil,
  then a wildcard (INADDR_ANY) is used.

  Note that the hostName is resolved when the internalAddressRepresentation
  is requested.
 */

@interface NGInternetSocketAddress : NSObject < NSCopying, NSCoding, NGSocketAddress >
{
@private
  void     *address; /* ptr to struct sockaddr_in */
  NSString *hostName;
  BOOL     isAddressFilled;
  BOOL     isHostFilled;
  BOOL     isWildcardHost;
}

+ (id)addressWithPort:(int)_port onHost:(id)_host;
+ (id)addressWithPort:(int)_port; // localhost
- (id)initWithPort:(int)_port onHost:(id)_host; // designated init
- (id)initWithPort:(int)_port;    // localhost

// these throw NGDidNotFindServiceException if the service is not found
+ (id)addressWithService:(NSString *)_serviceName
  onHost:(id)_host protocol:(NSString *)_protocol;
+ (id)addressWithService:(NSString *)_serviceName protocol:(NSString *)_proto;
- (id)initWithService:(NSString *)_serviceName onHost:(id)_host
  protocol:(NSString *)_protocol;
- (id)initWithService:(NSString *)_serviceName protocol:(NSString *)_protocol;

+ (id)wildcardAddress;
+ (id)wildcardAddressWithPort:(int)_port;

/* accessors */

- (NSString *)hostName;
- (NSString *)address;
- (int)port;

- (BOOL)isWildcardAddress;

/* testing for equality */

- (BOOL)isEqualToAddress:(NGInternetSocketAddress *)_addr;
- (BOOL)isEqual:(id)_obj;

/* description */

- (NSString *)stringValue; // returns 'hostname:port' as used in URLs
- (NSString *)description;

/* NGSocketAddress */

// throws NGCouldNotResolveHostNameException
- (void *)internalAddressRepresentation;

- (int)addressRepresentationSize;
- (id)domain;

@end

@interface NGActiveSocket(NGInternetActiveSocket)

// this method calls +socketConnectedToAddress: with an NGInternetSocketAddress
+ (id)socketConnectedToPort:(int)_port onHost:(id)_host;

// this method calls -connectToAddress: with an NGInternetSocketAddress
- (BOOL)connectToPort:(int)_port onHost:(id)_host;

@end

#endif /* __NGNet_NGInternetSocketAddress_H__ */
