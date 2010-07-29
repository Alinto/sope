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

#ifndef __NGNet_NGLocalSocketAddress_H__
#define __NGNet_NGLocalSocketAddress_H__

#if !defined(WIN32) || defined(__CYGWIN32__)

/*
  UNIX domain sockets, currently not available on Windows

  The Win32 local sockets are done using so called 'named pipes'.
*/

#include <NGStreams/NGSocketProtocols.h>

/*
  Represents a UNIX domain socket address (AF_LOCAL) or a named pipe (Win32).

  Socket addresses are immutable. -copy therefore returns a retained self.

  Note that when a local socket address is archived it stores the host together
  with the path. This ensures that the address-space will be the same on
  unarchiving, otherwise it will return an error.
*/

@interface NGLocalSocketAddress : NSObject < NSCopying, NGSocketAddress >
{
@private
#if defined(__WIN32__) && !defined(__CYGWIN32__)
  NSString *path;
#else
  void *address; /* ptr to struct sockaddr_un */
#endif
}

+ (id)addressWithPath:(NSString *)_path;
+ (id)address;
- (id)initWithPath:(NSString *)_path; // designated initializer
- (id)init;                           // creates unique path (pid,thread-id,cnt)

/* accessors */

- (NSString *)path;

/* testing for equality */

- (BOOL)isEqualToAddress:(NGLocalSocketAddress *)_addr;
- (BOOL)isEqual:(id)_obj;

/* test for accessibility */

- (BOOL)canSendOnAddress;
- (BOOL)canReceiveOnAddress;

@end

#endif /* !WIN32 */

#endif /* __NGNet_NGLocalSocketAddress_H__ */
