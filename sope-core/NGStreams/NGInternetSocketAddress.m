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
#if defined(__APPLE__)
#  include <netdb.h>
#endif

#if !defined(__CYGWIN32__)
#  if HAVE_WINDOWS_H
#    include <windows.h>
#  endif
#  if HAVE_WINSOCK_H
#    include <winsock.h>
#  endif
#endif

#include "NGSocketExceptions.h"
#include "NGInternetSocketAddress.h"
#include "NGInternetSocketDomain.h"
#include "common.h"

#if defined(HAVE_GETHOSTBYNAME_R) && !defined(linux) && !defined(__FreeBSD__)
#define USE_GETHOSTBYNAME_R 1
#endif

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
    
    TODO: cache some information, takes quite some time (11% of execution
    time on MacOSX proftest) to get the hostname of an address.
  */
  struct hostent *hostEntity = NULL; // only valid during lock
  NSString       *newHost  = nil;
  int            errorCode = 0;
  struct sockaddr_in *sockAddr = self->address;
  
  if (self->isHostFilled)
    /* host is already filled .. */
    return;

#if DEBUG
  NSAssert(self->isAddressFilled, @"either host or address must be filled ...");
#endif
  
  if (sockAddr->sin_addr.s_addr != 0) { // not a wildcard address
#if !defined(HAVE_GETHOSTBYADDR_R)
    [systemLock lock];
    newHost = NSMapGet(nameCache, 
		       (void *)(unsigned long)sockAddr->sin_addr.s_addr);
#else
    [systemLock lock];
    newHost = NSMapGet(nameCache, 
		       (void *)(unsigned long)sockAddr->sin_addr.s_addr);
    [systemLock unlock];
#endif
    if (newHost == nil) { 
      BOOL done = NO;
      
      while (!done) {
#if USE_GETHOSTBYNAME_R
        struct hostent hostEntityBuffer;
        char buffer[8200];

        hostEntity = gethostbyaddr_r((char *)&(sockAddr->sin_addr.s_addr),
                                     4,
                                     [[self domain] socketDomain],
                                     &hostEntityBuffer,
                                     buffer, 8200,
                                     &errorCode);
#else
# ifdef __MINGW32__
#   warning "doesn't resolve host name on mingw32 !"
	hostEntity = NULL;
	errorCode  = -1;
# else
        hostEntity = gethostbyaddr((char *)&(sockAddr->sin_addr.s_addr),
                                   4,
                                   [[self domain] socketDomain]);
#  if defined(WIN32) && !defined(__CYGWIN32__)
        errorCode = WSAGetLastError();
#  else
        errorCode = h_errno;
#  endif
# endif
#endif
        if (hostEntity == NULL) {
          done = YES;
          
          switch (errorCode) {
#ifdef __MINGW32__
	    case -1:
	      break;
#endif
            case HOST_NOT_FOUND:
              NSLog(@"%s: host not found ..", __PRETTY_FUNCTION__);
              break;
              
            case TRY_AGAIN:
#ifndef __linux
              NSLog(@"%s:\n  couldn't lookup host, retry ..",
                    __PRETTY_FUNCTION__);
              done = NO;
#else
              NSLog(@"%s: couldn't lookup host ..", __PRETTY_FUNCTION__);
#endif
              break;
            
            case NO_RECOVERY:
              NSLog(@"%s: no recovery", __PRETTY_FUNCTION__);
              break;
            
            case NO_DATA:
              NSLog(@"%s: no data", __PRETTY_FUNCTION__);
              break;
            
            default:
              NSLog(@"%s: unknown error: h_errno=%i errno=%s",
                    __PRETTY_FUNCTION__,
                    errorCode, strerror(errno));
              break;
          }
          
          newHost = [NSString stringWithCString:inet_ntoa(sockAddr->sin_addr)];
        }
        else {
          newHost = [NSString stringWithCString:hostEntity->h_name];
          done = YES;
        }
      }

      if (hostEntity == NULL) {
        // throw could not get address ..
        NSLog(@"could not get DNS name of address %@ in domain %@: %i",
              newHost, [self domain], errorCode);
      }
      else if (newHost) {
        /* add to cache */
        NSMapInsert(nameCache, 
		    (void *)(unsigned long)sockAddr->sin_addr.s_addr, newHost);
      }
      /* TODO: should also cache unknown IPs ! */
    }
    
    //else printf("%s: CACHE HIT !\n", __PRETTY_FUNCTION__);
    
#if !defined(HAVE_GETHOSTBYADDR_R)
    [systemLock unlock];
#endif
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
  
#if defined(WIN32) && !defined(__CYGWIN32__)
  u_long *ia = &(((struct sockaddr_in *)self->address)->sin_addr.s_addr);
#else
  unsigned int *ia = &(((struct sockaddr_in *)self->address)->sin_addr.s_addr);
#endif
  
  if (self->isAddressFilled)
    /* address is already filled .. */
    return nil;
  
#if DEBUG
  NSAssert(self->isHostFilled, @"either host or address must be filled ...");
#endif
  
  if (self->hostName == nil) {
    //  if ([self isWildcardAddress])
    *ia = htonl(INADDR_ANY); // wildcard (0)
    self->isAddressFilled = YES;
  }
  else {
    const unsigned char *chost;
    
    chost = (unsigned char *)[[self hostName] cString];
    
    // try to interpret hostname as INET dotted address (eg 122.133.44.87)
    *ia = inet_addr((char *)chost);
    
    if ((int)*ia != -1) { // succeeded
      self->isAddressFilled = YES;
    }
    else { // failed, try to interpret hostname as DNS hostname
      BOOL didFail   = NO;
      int  errorCode = 0;
      int  addrType  = AF_INET;
#if defined(USE_GETHOSTBYNAME_R)
      char buffer[4096];
      struct hostent hostEntity;
#else
      struct hostent *hostEntity; // only valid during lock
#endif

#if defined(USE_GETHOSTBYNAME_R)
      if (gethostbyname_r(chost, &hostEntity,
                          buffer, sizeof(buffer), &errorCode) == NULL) {
        didFail = YES;
      }
      else {
        addrType = hostEntity.h_addrtype;

        if (addrType == AF_INET)
          *ia = ((struct in_addr *)(hostEntity.h_addr_list[0]))->s_addr;
        else
          didFail = YES; // invalid domain (eg AF_INET6)
      }
#else
      [systemLock lock];
      {
        if ((hostEntity = gethostbyname((char *)chost)) == NULL) {
          didFail = YES;
#if defined(WIN32) && !defined(__CYGWIN32__)
          errorCode = WSAGetLastError();
#else
          errorCode = h_errno;
#endif
        }
        else {
          addrType = hostEntity->h_addrtype;
          
          if (addrType == AF_INET)
            *ia = ((struct in_addr *)(hostEntity->h_addr_list[0]))->s_addr;
          else
            didFail = YES; // invalid domain (eg AF_INET6)
        }
      }
      [systemLock unlock];
#endif

      if (didFail) { // could not resolve hostname
        // did not find host
        NSString *reason = nil;

        if (addrType != AF_INET) {
          // invalid domain (eg AF_INET6)
          reason = @"resolved address is in invalid domain";
        }
        else {
          switch (errorCode) {
            case HOST_NOT_FOUND: reason = @"host not found"; break;
            case TRY_AGAIN:      reason = @"try again";      break;
            case NO_RECOVERY:    reason = @"no recovery";    break;
            case NO_DATA:        reason = @"no address available"; break;
            default:
              reason = [NSString stringWithFormat:@"error code %i", errorCode];
              break;
          }
        }
        return [[[NGCouldNotResolveHostNameException alloc]
		  initWithHostName:[self hostName] reason:reason] autorelease];
      }

      self->isAddressFilled = YES;
    }
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
    self->address = malloc(sizeof(struct sockaddr_in));
  }
  return self;
}

- (id)initWithPort:(int)_port onHost:(id)_host { /* designated initializer */
  if ((self = [self init])) {
    self->isAddressFilled = NO;
    self->isHostFilled    = YES;
    
    if (_host != nil) {
      if ([_host isKindOfClass:[NSHost class]])
        _host = [(NSHost *)_host address];
      
      if ([_host isEqualToString:@"*"]) {
        self->hostName = nil; /* wildcard host */
      }
      else {
        self->hostName = [_host copy];
        self->isWildcardHost = NO;
      }
    }
    else {
      /* wildcard host */
      self->isWildcardHost = YES;
    }
    
    ((struct sockaddr_in *)self->address)->sin_family =
      [[self domain] socketDomain];
    ((struct sockaddr_in *)self->address)->sin_port =
      htons((short)(_port & 0xffff));
  }
  return self;
}

- (id)initWithService:(NSString *)_serviceName onHost:(id)_host
  protocol:(NSString *)_protocol
{
  /* careful: the port in servent is in network byteorder! */
  NSException *exc = nil;
  int port = -1;
#if defined(HAVE_GETSERVBYNAME_R)
  char   buffer[2048];
  struct servent entry;
#else
  struct servent *entry;
#endif
  
#if defined(HAVE_GETSERVBYNAME_R)
  if (getservbyname_r((char *)[_serviceName cString], [_protocol cString],
                      &entry, buffer, sizeof(buffer)) == NULL) {
    exc = [[NGDidNotFindServiceException alloc] initWithServiceName:_serviceName];
  }
  else
    port = entry.s_port;
#else
  [systemLock lock];
  {
    entry = getservbyname((char *)[_serviceName cString], [_protocol cString]);
    if (entry == NULL) {
      exc = [[NGDidNotFindServiceException alloc] 
	      initWithServiceName:_serviceName];
    }
    else
      port = entry->s_port;
  }
  [systemLock unlock];
#endif

  if (exc != nil) {
    self = [self autorelease];
    [exc raise];
    return nil;
  }
  return [self initWithPort:ntohs(port) onHost:_host];
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
  struct sockaddr_in *sockAddr = _representation;
#if DEBUG
  NSAssert(_length == sizeof(struct sockaddr_in),
           @"invalid socket address length");
#else
  if (_length != sizeof(struct sockaddr_in)) {
    NSLog(@"%s: got invalid sockaddr_in size ...", __PRETTY_FUNCTION__);
    [self release];
    return nil;
  }
#endif
  
  if ((self = [self init]) == nil)
    return nil;
  
  self->isHostFilled = NO; /* need to lookup DNS */
  
  /* fill address */
  
  self->isAddressFilled = YES;
  memcpy(self->address, _representation, sizeof(struct sockaddr_in));
  
  if (sockAddr->sin_addr.s_addr != 0) {
    /* not a wildcard address */
    self->isWildcardHost = NO;
  }
  else {
    /* wildcard address */
    self->hostName       = nil;
    self->isWildcardHost = YES;
    self->isHostFilled   = YES; /* wildcard host, no DNS lookup ... */
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
- (NSString *)address {
#if defined(WIN32) && !defined(__CYGWIN32__)
  u_long *ia;
  ia = (u_long *)&(((struct sockaddr_in *)self->address)->sin_addr.s_addr);
#else
  unsigned long ia;
  ia = (unsigned long)
    &(((struct sockaddr_in *)self->address)->sin_addr.s_addr);
#endif

  if (self->hostName == nil) /* wildcard */
    return nil;
  
  if (!self->isAddressFilled)
    [[self _fillAddress] raise];

  {
    char     *ptr = NULL;
    NSString *str = nil;
    
    [systemLock lock];
    {
      ptr = inet_ntoa(*((struct in_addr *)ia));
      str = [NSString stringWithCString:ptr];
    }
    [systemLock unlock];

    return str;
  }
}

- (int)port {
  /* how to do ? */
  if (!self->isAddressFilled)
    [[self _fillAddress] raise];
  return ntohs(((struct sockaddr_in *)self->address)->sin_port);
}

- (BOOL)isWildcardAddress {
  if (self->isWildcardHost) return YES;
  return ([self hostName] == nil) || ([self port] == 0);
}

/* NGSocketAddress protocol */

- (void *)internalAddressRepresentation {
  // throws
  //   NGCouldNotResolveHostNameException  when a DNS lookup fails
  
  if (!self->isAddressFilled)
    [[self _fillAddress] raise];
  
  return self->address;
}

- (int)addressRepresentationSize {
  return [[self domain] addressRepresentationSize];
}
- (id)domain {
  static id domain = nil;
  if (domain == nil) domain = [[NGInternetSocketDomain domain] retain];
  return domain;
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
