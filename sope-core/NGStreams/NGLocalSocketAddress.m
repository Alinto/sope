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

#if !defined(WIN32) || defined(__CYGWIN32__)

#include "NGSocketExceptions.h"
#include "NGLocalSocketAddress.h"
#include "NGLocalSocketDomain.h"
#import <Foundation/NSString.h>

#include "config.h"

#if defined(__APPLE__) || defined(__FreeBSD__)
#  include <sys/types.h>
#else
#  include <sys/un.h>
#endif

#if defined(HAVE_UNISTD_H) || defined(__APPLE__)
#  include <unistd.h>
#endif

#ifndef SUN_LEN
#define SUN_LEN(su) \
        (sizeof(*(su)) - sizeof((su)->sun_path) + strlen((su)->sun_path))
#endif

#include "common.h"

#ifndef AF_LOCAL
#  define AF_LOCAL AF_UNIX
#endif

#if defined(__WIN32__) && !defined(__CYGWIN32__)
static NSString *socketDirectoryPath = @"\\\\.\\pipe\\";
#else
static NSString *socketDirectoryPath = @"/tmp";
#endif

@implementation NGLocalSocketAddress

+ (id)addressWithPath:(NSString *)_p {
  return [[(NGLocalSocketAddress *)[self alloc] initWithPath:_p] autorelease];
}
+ (id)address {
  return [[[self alloc] init] autorelease];
}

- (id)initWithPath:(NSString *)_path {
  if ((self = [super init])) {
    self->address = calloc(1, sizeof(struct sockaddr_un));
    
    memset(self->address, 0, sizeof(struct sockaddr_un));
    
#if defined(__WIN32__) && !defined(__CYGWIN32__)
    self->path = [_path copyWithZone:[self zone]];
#else
    if ([_path cStringLength] >=
        sizeof(((struct sockaddr_un *)self->address)->sun_path)) {
      
      NSLog(@"LocalDomain name too long: maxlen=%i, len=%i, path=%@",
            sizeof(((struct sockaddr_un *)self->address)->sun_path),
            [_path cStringLength],
            _path);
      [NSException raise:NSInvalidArgumentException
                   format:@"path to long as local domain socket address !"];
      [self release];
      return nil;
    }
    
    ((struct sockaddr_un *)self->address)->sun_family =
      [[self domain] socketDomain];

    [_path getCString:((struct sockaddr_un *)self->address)->sun_path
           maxLength:sizeof(((struct sockaddr_un *)self->address)->sun_path)];
#endif
  }
  return self;
}

- (id)init {
  int      addressCounter = 0;
  NSString *newPath;
  
  newPath = [NSString stringWithFormat:@"_ngsocket_%p_%p_%03d",
                        getpid(), [NSThread currentThread], addressCounter];
  newPath = [socketDirectoryPath stringByAppendingPathComponent:newPath];

  return [self initWithPath:newPath];
}

- (id)initWithDomain:(id)_domain
  internalRepresentation:(void *)_representation
  size:(int)_length
{
  // this method is used by the address factory
  struct sockaddr_un *nun = _representation;
  NSString *path;

  path = (_length < 3)
    ? (id)@""
    : [[NSString alloc] initWithCString:nun->sun_path];
  
  self = [self initWithPath:path];
  [path release]; path = nil;
  return self;
}

- (void)dealloc {
  if (self->address) free(self->address);
  [super dealloc];
}

/* accessors */

- (NSString *)path {
  const char *sp;

  sp = ((struct sockaddr_un *)self->address)->sun_path;
  if (strlen(sp) == 0)
    return @"";
  
  return [NSString stringWithCString:sp];
}

/* operations */

- (void)deletePath {
  const char *sp;
  
  sp = ((struct sockaddr_un *)self->address)->sun_path;
  if (strlen(sp) == 0)
    return;
  
  unlink(sp);
}

// NGSocketAddress protocol

- (void *)internalAddressRepresentation {
  return self->address;
}
- (int)addressRepresentationSize { // varies in length
  return SUN_LEN(((struct sockaddr_un *)self->address));
}
- (id)domain {
  return [NGLocalSocketDomain domain];
}

/* test for accessibility */

- (BOOL)canSendOnAddress {
  return (access(((struct sockaddr_un *)self->address)->sun_path, W_OK) == 0)
    ? YES : NO;
}
- (BOOL)canReceiveOnAddress {
  return (access(((struct sockaddr_un *)self->address)->sun_path, R_OK) == 0)
    ? YES : NO;
}

/* testing for equality */

- (BOOL)isEqualToAddress:(NGLocalSocketAddress *)_addr {
  return [[_addr path] isEqualToString:[self path]];
}

- (BOOL)isEqual:(id)_object {
  if (_object == self) return YES;
  if ([_object class] != [self class]) return NO;
  return [self isEqualToAddress:_object];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* socket addresses are immutable, just retain on copy ... */
  return [self retain];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
  [_encoder encodeObject:[[NSHost currentHost] name]];
  [_encoder encodeObject:[self path]];
}

- (id)initWithCoder:(NSCoder *)_decoder {
  NSString *hostName = [_decoder decodeObject];
  NSString *path     = [_decoder decodeObject];

  NSAssert([path isKindOfClass:[NSString class]], @"path must be a string ..");

  if (![hostName isEqualToString:[[NSHost currentHost] name]]) {
    NSLog(@"unarchived local socket address on a different host, "
          @"encoded on %@, decoded on %@ (path=%@)",
          hostName, [[NSHost currentHost] name], path);
  }

  return [self initWithPath:path];
}

/* description */

- (NSString *)stringValue {
  NSString *p = [self path];
  return [p length] == 0 ? (NSString *)@"*" : p;
}

- (NSString *)description {
  NSString *p = [self path];
  
  if ([p length] == 0)
    p = @"[no path]";

  return [NSString stringWithFormat:@"<0x%p[%@]: %@>",
                     self, NSStringFromClass([self class]), p];
}

@end /* NGLocalSocketAddress */

#endif /* !WIN32 */
