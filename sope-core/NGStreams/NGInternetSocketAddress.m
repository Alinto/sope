/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2022 Nicolas Höft

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

#include "common.h"

#if HAVE_SYS_TYPES_H || defined(__APPLE__)
#  include <sys/types.h>
#endif
#if HAVE_NETINET_IN_H
#  include <netinet/in.h>
#endif
#if HAVE_UNISTD_H || defined(__APPLE__)
#  include <unistd.h>
#endif
#ifdef HAVE_NETDB_H
#  include <netdb.h>
#endif


#include "NGSocketExceptions.h"
#include "NGInternetSocketAddress.h"
#include "NGInternetSocketDomain.h"
#include "common.h"

@implementation NGInternetSocketAddress

#if LIB_FOUNDATION_LIBRARY
extern NSRecursiveLock *libFoundationLock;
#define systemLock libFoundationLock
#else
static NSRecursiveLock *systemLock = nil;
#endif

static NSMapTable *nameCache = NULL;

+ (void)initialize {
  [NGSocket initialize];

  if (nameCache == NULL) {
    nameCache = NSCreateMapTable(NSIntMapKeyCallBacks,
                                 NSObjectMapValueCallBacks,
                                 128);
  }

#if !LIB_FOUNDATION_LIBRARY
  [[NSNotificationCenter defaultCenter]
                         addObserver:self selector:@selector(taskNowMultiThreaded:)
                         name:NSWillBecomeMultiThreadedNotification
                         object:nil];
#endif
}

+ (void)taskNowMultiThreaded:(NSNotification *)_notification {
  if (systemLock == nil) systemLock = [[NSRecursiveLock alloc] init];
}

static inline NSString *_nameOfLocalhost(void) {
#if 1
  return [[NSHost currentHost] name];
#else
  NSString *hostName = nil;

  [systemLock lock];
  {
    char buffer[1024];
    gethostname(buffer, sizeof(buffer));
    hostName = [[NSString alloc] initWithCString:buffer];
  }
  [systemLock unlock];

  return [hostName autorelease];
#endif
}

- (void)_fillHost {
  /*
    Fill up the host and port ivars based on the INET address.
  */
  NSString       *newHost  = nil;
  int            errorCode = 0;

  if (self->isHostFilled)
    /* host is already filled .. */
    return;

#if DEBUG
  NSAssert(self->address != nil, @"either host or address must be filled ...");
#endif

  if (!self->isWildcardHost) {
    if (newHost == nil) {
      BOOL done = NO;

      while (!done) {
        char hostNameBuffer[256];

        errorCode = getnameinfo((struct sockaddr *)self->address, [self addressRepresentationSize],
                                hostNameBuffer, 255, NULL, 0, 0);

        if (errorCode != 0) {
          done = YES;

          switch (errorCode) {
            case EAI_NONAME:
              NSLog(@"%s: host not found ..", __PRETTY_FUNCTION__);
              break;

            case EAI_AGAIN:
#ifndef __linux
              NSLog(@"%s:\n  couldn't lookup host, retry ..",
                    __PRETTY_FUNCTION__);
              done = NO;
#else
              NSLog(@"%s: couldn't lookup host ..", __PRETTY_FUNCTION__);
#endif
              break;

            case EAI_FAIL:
              NSLog(@"%s: A nonrecoverable error occurred.", __PRETTY_FUNCTION__);
              break;

            default:
              NSLog(@"%s: unknown error: h_errno=%i errno=%s",
                    __PRETTY_FUNCTION__,
                    errorCode, gai_strerror(errorCode));
              break;
          }

          newHost = self->ipAddress;
        }
        else {
          newHost = [NSString stringWithCString:hostNameBuffer];
          done = YES;
        }
      }

      if (errorCode != 0) {
        // throw could not get address ..
        NSLog(@"could not get DNS name of address %@ in domain %@: %s",
               self->ipAddress, [self domain], gai_strerror(errorCode));
      }
    }
  }
  else {
    /* wildcard address */
    newHost = nil;
  }

  ASSIGNCOPY(self->hostName, newHost);
  self->isHostFilled = YES;
}

- (NSException *)_fillAddress {
  /*
    Fill up the INET address based on the host and port ivars.
  */
  // throws
  //   NGCouldNotResolveHostNameException  when a DNS lookup fails

  if (self->address != nil)
    /* address is already filled .. */
    return nil;

#if DEBUG
  NSAssert(self->isHostFilled, @"either host or address must be filled ...");
#endif

  if (self->hostName == nil) {
    if (self->isIp6) {
      struct sockaddr_in6 *addr6 = malloc(sizeof(struct sockaddr_in6));
      addr6->sin6_addr = in6addr_any;
      addr6->sin6_port = htons(self->port);
      self->address = addr6;
    }
    else
    {
      struct sockaddr_in *addr = malloc(sizeof(struct sockaddr_in));
      addr->sin_addr.s_addr = htonl(INADDR_ANY);
      addr->sin_port = htons(self->port);
      self->address = addr;
    }
    self->ipAddress = @"*";
  }
  else {
    const char *chost;
    struct addrinfo hint;
    struct addrinfo* res = NULL;
    void* addr_ptr;
    char ipAddr[64];
    memset(&hint, 0, sizeof(hint));
    int ret;

    // try to interpret hostname as INET/INET6 dotted address (eg 122.133.44.87)
    chost = [[self hostName] cString];
    hint.ai_family = PF_UNSPEC;
    hint.ai_flags |= AI_CANONNAME;
    ret = getaddrinfo(chost, NULL, &hint, &res);
    if (ret != 0)
    {
      NSString* reason = [NSString stringWithFormat:@"error code %s", gai_strerror(ret)];
      return [[[NGCouldNotResolveHostNameException alloc]
                  initWithHostName:[self hostName] reason:reason] autorelease];
    }
    if (res->ai_family == AF_INET) {
      struct sockaddr_in *addr = (struct sockaddr_in *)malloc(sizeof(struct sockaddr_in));
      addr->sin_family = AF_INET;
      addr->sin_port = htons(self->port);
      memcpy(&addr->sin_addr, &((struct sockaddr_in *) res->ai_addr)->sin_addr, sizeof(struct in_addr));
      self->address = addr;
      self->isIp6 = NO;
      self->isWildcardHost = (addr->sin_addr.s_addr == INADDR_ANY);
      addr_ptr = &addr->sin_addr;
    }
    else if (res->ai_family == AF_INET6) {
      struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)malloc(sizeof(struct sockaddr_in6));
      addr6->sin6_family = AF_INET6;
      addr6->sin6_port = htons(self->port);
      memcpy(&addr6->sin6_addr, &((struct sockaddr_in6 *) res->ai_addr)->sin6_addr, sizeof(struct in6_addr));
      self->address = addr6;
      self->isWildcardHost = IN6_IS_ADDR_UNSPECIFIED(&addr6->sin6_addr);
      self->isIp6 = YES;
      addr_ptr = &addr6->sin6_addr;
    }
    inet_ntop(res->ai_family, addr_ptr, ipAddr, 64);
    freeaddrinfo(res);
    self->ipAddress = [NSString stringWithUTF8String: ipAddr];
    self->isAddressFilled = YES;
  }
  return nil;
}

/* constructors */

+ (id)addressWithPort:(int)_port onHost:(id)_host {
  return [[[self alloc] initWithPort:_port onHost:_host] autorelease];
}
+ (id)addressWithPort:(int)_port {
  return [[[self alloc] initWithPort:_port] autorelease];
}

+ (id)addressWithService:(NSString *)_sname onHost:(id)_host
  protocol:(NSString *)_protocol
{
  return [[[self alloc] initWithService:_sname
                        onHost:_host
                        protocol:_protocol]
                        autorelease];
}
+ (id)addressWithService:(NSString *)_sname protocol:(NSString *)_protocol {
  return [[[self alloc] initWithService:_sname protocol:_protocol] autorelease];
}

+ (id)wildcardAddress {
  return [[[self alloc] initWithPort:0 onHost:@"*"] autorelease];
}
+ (id)wildcardAddressWithPort:(int)_port {
  return [[[self alloc] initWithPort:_port onHost:@"*"] autorelease];
}

- (id)init {
  if ((self = [super init])) {
    self->address = NULL;
  }
  return self;
}

- (id)initWithPort:(int)_port onHost:(id)_host { /* designated initializer */
  if ((self = [self init])) {
    self->isAddressFilled = NO;
    self->isHostFilled    = YES;
    self->port = _port;

    if (_host != nil) {
      if ([_host isKindOfClass:[NSHost class]])
        _host = [(NSHost *)_host address];

      if ([_host isEqualToString:@"*"]) {
        self->hostName = nil; /* wildcard host */
        self->isWildcardHost = YES;
      }
      else {
        self->hostName = [_host copy];
        self->isWildcardHost = NO;
        [self _fillAddress];
      }
    }
    else {
      /* wildcard host */
      self->isWildcardHost = YES;
    }
  }
  return self;
}

- (id)initWithService:(NSString *)_serviceName onHost:(id)_host
  protocol:(NSString *)_protocol
{
  /* careful: the port in servent is in network byteorder! */
  NSException *exc = nil;
  struct addrinfo* res = NULL;
  struct addrinfo hint = {0};
  hint.ai_family = AF_UNSPEC;
  hint.ai_flags = AI_PASSIVE;
  if ([_protocol isEqualToString: @"tcp"])
    hint.ai_socktype = SOCK_STREAM;
  else if ([_protocol isEqualToString: @"udp"])
    hint.ai_socktype = SOCK_DGRAM;
  int _port = -1;
  int ret;

  ret = getaddrinfo(NULL, [_serviceName cString], &hint, &res);
  if (ret != 0) {
    exc = [[NGDidNotFindServiceException alloc] initWithServiceName:_serviceName];
  }
  else {
    if (res->ai_family == AF_INET)
      _port = ((struct sockaddr_in *) res->ai_addr)->sin_port;
    else if (res->ai_family == AF_INET6)
      _port = ((struct sockaddr_in6 *) res->ai_addr)->sin6_port;
  }
  freeaddrinfo(res);

  if (exc != nil) {
    self = [self autorelease];
    [exc raise];
    return nil;
  }
  return [self initWithPort:ntohs(_port) onHost:_host];
}

- (id)initWithPort:(int)_port {
  return [self initWithPort:_port onHost:_nameOfLocalhost()];
}

- (id)initWithService:(NSString *)_serviceName protocol:(NSString *)_protocol {
  return [self initWithService:_serviceName
               onHost:_nameOfLocalhost()
               protocol:_protocol];
}

- (id)initWithDomain:(id)_domain
  internalRepresentation:(void *)_representation
  size:(int)_length
{
  struct sockaddr *sockAddr = _representation;
  char ipAddr[64];
  void* addr_ptr;
#if DEBUG
  NSAssert(_length == [_domain addressRepresentationSize],
           @"invalid socket address length");
#else
  if (_length != [_domain addressRepresentationSize]) {
    NSLog(@"%s: got invalid sockaddr_in size ...", __PRETTY_FUNCTION__);
    [self release];
    return nil;
  }
#endif

  if ((self = [self init]) == nil)
    return nil;

  self->isHostFilled = NO; /* need to lookup DNS */

  /* fill address */
  if (sockAddr->sa_family == AF_INET) {
    self->address = malloc(sizeof(struct sockaddr_in));
    struct sockaddr_in *addr4 = (struct sockaddr_in *)sockAddr;
    addr_ptr = &addr4->sin_addr;
    self->isIp6 = NO;
    self->isWildcardHost = (addr4->sin_addr.s_addr == INADDR_ANY);
    self->port = ntohs(addr4->sin_port);
  }
  else if (sockAddr->sa_family == AF_INET6) {
    self->address = malloc(sizeof(struct sockaddr_in6));
    struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)sockAddr;
    addr_ptr = &addr6->sin6_addr;
    self->isIp6 = YES;
    self->isWildcardHost = IN6_IS_ADDR_UNSPECIFIED(&addr6->sin6_addr);
    self->port = ntohs(addr6->sin6_port);
  }

  memcpy(self->address, _representation, [_domain addressRepresentationSize]);
  self->isAddressFilled = YES;

  if (!self->isWildcardHost) {
    /* not a wildcard address */
    inet_ntop(sockAddr->sa_family, addr_ptr, ipAddr, 64);
    self->ipAddress = [NSString stringWithUTF8String: ipAddr];
  }
  else {
    /* wildcard address */
    self->hostName       = nil;
    self->isHostFilled   = YES; /* wildcard host, no DNS lookup ... */
    self->ipAddress = @"*";
  }

  return self;
}

- (void)dealloc {
  [self->hostName release];
  if (self->address) free(self->address);
  [super dealloc];
}

/* accessors */

- (NSString *)hostName {
  if (!self->isHostFilled) [self _fillHost];
  return [[self->hostName copy] autorelease];
}

- (BOOL) _isLoopback {
  if (self->address == nil)
    [[self _fillAddress] raise];
  if (self->isIp6) {
      return IN6_IS_ADDR_LOOPBACK(&((struct sockaddr_in6 *)self->address)->sin6_addr);
  }
  unsigned int *ia = &(((struct sockaddr_in *)self->address)->sin_addr.s_addr);
  return ((((long int) (ntohl(*ia))) & 0xff000000) == 0x7f000000);
}

- (NSString *)address {
  if (self->hostName == nil) /* wildcard */
    return nil;

  if (self->address == nil)
    [[self _fillAddress] raise];
  return self->ipAddress;
}

- (int)port {
  return self->port;
}

- (BOOL)isWildcardAddress {
  if (self->isWildcardHost) return YES;
  return ([self hostName] == nil) || ([self port] == 0);
}

/* NGSocketAddress protocol */

- (void *)internalAddressRepresentation {
  // throws
  //   NGCouldNotResolveHostNameException  when a DNS lookup fails

  if (self->address == nil)
    [[self _fillAddress] raise];
  return self->address;
}

- (int)addressRepresentationSize {
  return [[self domain] addressRepresentationSize];
}


- (id)domain {
  static id domain = nil;
  static id domain6 = nil;
  if (domain == nil) domain = [[NGInternetSocketDomain domain] retain];
  if (domain6 == nil) domain6 = [[NGInternetSocketDomain6 domain] retain];
  if (self->isIp6)
    return domain6;
  return domain;
}

- (BOOL) isLocalhost {
  NSString *normalized_hostname;

  if (![self hostName])
    return NO;

  if ([self _isLoopback])
    return YES;
  // normalize the string
  normalized_hostname = [[self hostName] lowercaseString];

  if ([normalized_hostname hasSuffix: @"."]) {
    normalized_hostname = [normalized_hostname substringToIndex: [normalized_hostname length] - 1];
  }

  if ([normalized_hostname isEqualToString: @"localhost"] ||
      [normalized_hostname isEqualToString: @"localhost.localdomain"] ||
      [normalized_hostname hasSuffix: @".localhost"]) {
    return YES;
  }
  return NO;
}

- (BOOL) isIPv4 {
  return !self->isIp6;
}

- (BOOL) isIPv6 {
  return self->isIp6;
}

/* comparing */

- (NSUInteger)hash {
  return [self port];
}

- (BOOL)isEqualToAddress:(NGInternetSocketAddress *)_otherAddress {
  if (self == _otherAddress)
    return YES;
  if (![[_otherAddress hostName] isEqualToString:[self hostName]])
    return NO;
  if ([_otherAddress port] != [self port])
    return NO;
  return YES;
}

- (BOOL)isEqual:(id)_object {
  if (_object == self) return YES;
  if ([_object class] != [self class]) return NO;
  return [self isEqualToAddress:_object];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  // socket addresses are immutable, therefore just retain self
  return [self retain];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
  int aPort = [self port];

  [_encoder encodeValueOfObjCType:@encode(int) at:&aPort];
  [_encoder encodeObject:[self hostName]];
}
- (id)initWithCoder:(NSCoder *)_decoder {
  int aPort;
  id  aHost;

  [_decoder decodeValueOfObjCType:@encode(int) at:&aPort];
  aHost = [_decoder decodeObject];

  return [self initWithPort:aPort onHost:aHost];
}

/* description */

- (NSString *)stringValue {
  NSString *name;

  if ((name = [self hostName]) == nil)
    name = @"*";

  return [NSString stringWithFormat:@"%@:%i", name, [self port]];
}

- (NSString *)description {
  NSMutableString *ms;
  id tmp;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if ((tmp = [self hostName]) != nil)
    [ms appendFormat:@" host=%@", tmp];
  else
    [ms appendString:@" *host"];

  if (!self->isAddressFilled)
    [ms appendString:@" not-filled"];
  else
    [ms appendFormat:@" port=%d", [self port]];

  //if (self->ipAddress != nil)
    //[ms appendFormat:@" ip=%@", self->ipAddress];

  [ms appendString:@">"];
  return ms;
}

@end /* NGInternetSocketAddress */

@implementation NGActiveSocket(NGInternetActiveSocket)

+ (id)socketConnectedToPort:(int)_port onHost:(id)_host {
  // this method calls +socketConnectedToAddress: with an
  // NGInternetSocketAddress

  return [self socketConnectedToAddress:
                 [NGInternetSocketAddress addressWithPort:_port onHost:_host]];
}

- (BOOL)connectToPort:(int)_port onHost:(id)_host {
  // this method calls -connectToAddress: with an NGInternetSocketAddress

  return [self connectToAddress:
                 [NGInternetSocketAddress addressWithPort:_port onHost:_host]];
}

@end /* NGActiveSocket(NGInternetActiveSocket) */
