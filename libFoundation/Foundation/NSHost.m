/* 
   NSHost.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Aleksandr Savostyanov <sav@conextions.com>
   Author: Ovidiu Predescu <ovidiu@net-community.com>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <config.h>

#ifdef HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

#if HAVE_NETINET_IN_H
# include <netinet/in.h>
#endif

#include <string.h>

#if HAVE_WINDOWS_H
#  include <windows.h>
#endif

#if defined(__MINGW32__)
#  include <winsock.h>
#else
#  include <netdb.h>
#  include <sys/socket.h>
#  include <arpa/inet.h>
#endif

#include <Foundation/common.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSThread.h>

extern NSRecursiveLock* libFoundationLock;

@interface NSHost(Private)
- (id)initWithHostEntity:(struct hostent *)hostEntity;
- (id)initWithName:(NSString*)name;
- (id)initWithDottedRepresentation:(NSString*)address;
@end

@implementation NSHost

static BOOL                cacheEnabled = YES;
static NSMutableDictionary *hostsByName = nil;
static NSMutableDictionary *hostsByAddress = nil;
static NSRecursiveLock     *hostsLock = nil;

+ (void)initialize
{
#ifdef __MINGW32__
    static WSADATA wsaData;
    WSAStartup(MAKEWORD(1, 1), &wsaData);
#endif
    hostsByName = [NSMutableDictionary new];
    hostsByAddress = [NSMutableDictionary new];
    [[NSNotificationCenter defaultCenter]
	addObserver:self
	selector:@selector(taskNowMultiThreaded:)
	name:NSWillBecomeMultiThreadedNotification
	object:nil];
}

+ (void)taskNowMultiThreaded:(NSNotification*)notification
{
    hostsLock = [NSRecursiveLock new];
}

+ (NSHost *)currentHost
{
    char buffer[1024];
    NSString *hostName;
    gethostname(buffer, 1024);
    hostName = [NSString stringWithCString:buffer];
    return [NSHost hostWithName:hostName];
}

+ (NSHost *)hostWithName:(NSString *)name
{
    return AUTORELEASE([[NSHost alloc] initWithName:name]);
}

+ (NSHost *)hostWithAddress:(NSString *)address
{
    return AUTORELEASE([[NSHost alloc] initWithDottedRepresentation:address]);
}

+ (void)setHostCacheEnabled:(BOOL)flag
{
    cacheEnabled = flag;
}

+ (BOOL)isHostCacheEnabled
{
    return cacheEnabled;
}

+ (void)flushHostCache
{
    [hostsByName    removeAllObjects];
    [hostsByAddress removeAllObjects];
}

- (void) dealloc
{
    RELEASE(self->names);
    RELEASE(self->addresses);
    [super dealloc];
}

- (BOOL)isEqualToHost:(NSHost *)aHost
{
    NSArray *theAddresses;
    int i, count;

    theAddresses = [aHost addresses];
    count = [theAddresses count];
    for (i = 0; i < count; i++) {
        if ([self->addresses containsObject:[theAddresses objectAtIndex:i]])
	    return YES;
    }

    return NO;
}

- (BOOL)isEqual:(id)anotherHost
{
    return [self isEqualToHost:anotherHost];
}

- (NSString *)name
{
    if ([self->names count])
        return [self->names objectAtIndex:0];
    return nil;
}

- (NSArray *)names
{
    return self->names;
}

- (NSString *)address
{
    if ([self->addresses count])
        return [self->addresses objectAtIndex:0];
    return nil;
}

- (NSArray *)addresses
{
    return self->addresses;
}

/* description */

- (NSString *)description
{
    return [NSString stringWithFormat:@"<0x%p[%@]: names=%@, addresses=%@>",
                       self, NSStringFromClass([self class]),
                       [self->names componentsJoinedByString:@","],
                       [self->addresses componentsJoinedByString:@","]];
}

@end /* NSHost */

@implementation NSHost(Private)

- (id)initWithName:(NSString*)name
{
#if HAVE_GETHOSTBYNAME_R && !defined(linux)
    struct hostent hostEntity;
    int            hErrno;
    // size as described in "UNIX Network Programming" by Richard Stevens
    char           buffer[8192]; 
#else
    struct hostent *hostEntity;
#endif

    if (cacheEnabled) {
	NSHost* host;

	[hostsLock lock];
	host = [hostsByName objectForKey:name];
	[hostsLock unlock];
	if (host) {
            RELEASE(self);
	    return RETAIN(host);
        }
    }

#if HAVE_GETHOSTBYNAME_R && !defined(linux)
    if (gethostbyname_r([name cString], &hostEntity,
                        buffer, sizeof(buffer), &hErrno) == NULL) {
        RELEASE(self);
        return nil;
    }

    self = [self initWithHostEntity:&hostEntity];
#else
    [libFoundationLock lock];
    hostEntity = gethostbyname((char*)[name cString]);
    if (!hostEntity) {
        RELEASE(self);
        [libFoundationLock unlock];
        return nil;
    }

    self = [self initWithHostEntity:hostEntity];
    [libFoundationLock unlock];
#endif

    return self;
}

- (id)initWithDottedRepresentation:(NSString*)address
{
#if HAVE_GETHOSTBYADDR_R && !defined(linux)
    struct hostent hostEntity;
    int            hErrno;
    // as described in "UNIX Network Programming" by Richard Stevens
    char           buffer[8192]; 
#else
    struct hostent *hostEntity;
#endif
    struct in_addr ipAddress;

    if (cacheEnabled) {
	NSHost* host;

	[hostsLock lock];
	host = [hostsByAddress objectForKey:address];
	[hostsLock unlock];
	if (host) {
            RELEASE(self);
	    return RETAIN(host);
        }
    }

    ipAddress.s_addr = inet_addr((char*)[address cString]);
    if (ipAddress.s_addr == INADDR_NONE) {
        RELEASE(self);
        return nil;
    }

#if HAVE_GETHOSTBYADDR_R && !defined(linux)
    if (gethostbyaddr_r((char*)&ipAddress, sizeof(ipAddress), AF_INET,
                        &hostEntity, buffer, sizeof(buffer), &hErrno) == NULL) {
        RELEASE(self);
        return nil;
    }
    self = [self initWithHostEntity:&hostEntity];
#else
    [libFoundationLock lock];
    hostEntity = gethostbyaddr((char*)&ipAddress, sizeof(ipAddress), AF_INET);
    if (!hostEntity) {
        RELEASE(self);
        [libFoundationLock unlock];
        return nil;
    }
    self = [self initWithHostEntity:hostEntity];
    [libFoundationLock unlock];
#endif

    return self;
}

- (id)initWithHostEntity:(struct hostent *)hostEntity
{
    char **ptr;
    struct in_addr ipAddress;

    self->names = [[NSMutableArray alloc] init];
    [self->names addObject:[NSString stringWithCString:hostEntity->h_name]];

    ptr = hostEntity->h_aliases;
    while(*ptr) {
        [self->names addObject:[NSString stringWithCString:*ptr]];
        ptr++;
    }

    self->addresses = [[NSMutableArray alloc] init];
    ptr = hostEntity->h_addr_list;
    while(*ptr) {
        memcpy(&ipAddress, *ptr, hostEntity->h_length);
        [self->addresses addObject:
		      [NSString stringWithCString:inet_ntoa(ipAddress)]];
        ptr++;
    }

    if (cacheEnabled) {
	int i, count;

	[hostsLock lock];
	for (i = 0, count = [self->names count]; i < count; i++) {
	    [hostsByName setObject:self forKey:[self->names objectAtIndex:i]];
        }
	for (i = 0, count = [self->addresses count]; i < count; i++) {
	    [hostsByAddress setObject:self
                            forKey:[self->addresses objectAtIndex:i]];
        }
	[hostsLock unlock];
    }

    return self;
}

@end /* NSHost(Private) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
