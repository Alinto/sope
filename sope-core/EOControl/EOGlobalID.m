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

#include "EOGlobalID.h"
#include "common.h"
#include <time.h>
#include <unistd.h>
#if !defined(__MINGW32__)
#  include <netdb.h>
#endif

@implementation EOGlobalID

- (BOOL)isTemporary {
  return NO;
}

- (id)copyWithZone:(NSZone *)_zone {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

@end /* EOGlobalID */

@implementation EOTemporaryGlobalID

static unsigned short sequence = 0;
static unsigned int   ip;

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    char buf[1024];
    struct hostent *hostEntry;
    
    isInitialized = YES;
    gethostname(buf, 1024);
    // THREADING
    if ((hostEntry = gethostbyname(buf))) {
      char **ptr;

      ptr = hostEntry->h_addr_list;
      if (*ptr) {
        NSAssert((unsigned)hostEntry->h_length >= sizeof(ip),
                 @"invalid host address !");
        memcpy(&ip, *ptr, sizeof(ip));
      }
      else {
        NSLog(@"WARNING: set IP address for EO key generation to 0.0.0.0 !");
        ip = 0;
      }
    }
    else {
      NSLog(@"WARNING: set IP address for EO key generation to 0.0.0.0 !");
      ip = 0;
    }
  }
}

+ (void)assignGloballyUniqueBytes:(unsigned char *)_buffer {
  struct {
    unsigned short sequence;
    unsigned short pid;
    unsigned int   time;
    unsigned int   ip;
  } *bufPtr;

  bufPtr = (void *)_buffer;
  bufPtr->sequence = sequence++;
#if defined(__WIN32__)
  bufPtr->pid      = (unsigned short)GetCurrentProcessId();
#else
  bufPtr->pid      = getpid();
#endif
  bufPtr->time     = time(NULL);
  bufPtr->ip       = ip;
}

- (id)init {
  [self->isa assignGloballyUniqueBytes:&(self->idbuffer[0])];
  return self;
}

- (BOOL)isTemporary {
  return YES;
}

- (BOOL)isEqual:(id)_other {
  return _other == self ? YES : NO;
#if 0
  EOTemporaryGlobalID *otherKey;
  
  if (_other == nil)  return NO;
  if (_other == self) return YES;
  otherKey = _other;
  if (otherKey->isa != self->isa) return NO;
  // compare bytes
  return NO;
#endif
}

@end /* EOTemporaryGlobalID */
