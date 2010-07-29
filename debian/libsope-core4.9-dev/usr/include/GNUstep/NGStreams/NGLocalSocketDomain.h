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

#ifndef __NGNet_NGLocalSocketDomain_H__
#define __NGNet_NGLocalSocketDomain_H__

#if !defined(WIN32)
// UNIX domain, not available on WIN32

#import <Foundation/NSObject.h>
#include <NGStreams/NGSocketProtocols.h>

/*
  Represents the AF_LOCAL (AF_UNIX) socket domain.

  NGLocalSocketDomain is a singleton, therefore on copy it returns itself and on
  unarchiving it replaces the unarchived instance with the singleton.
*/

@interface NGLocalSocketDomain : NSObject < NSCopying, NSCoding, NGSocketDomain >

+ (id)domain;

// NGSocketDomain

- (id<NGSocketAddress>)addressWithRepresentation:(void *)_data
  size:(unsigned int)_size;

- (int)socketDomain;
- (int)protocol;

@end

#define NGDefaultLocalSocketDomain [NGLocalSocketDomain domain]

#endif /* !WIN32 */

#endif /* __NGNet_NGLocalSocketDomain_H__ */
