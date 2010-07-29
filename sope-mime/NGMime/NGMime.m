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

#include "NGMime.h"

#ifndef LIBRARY_MAJOR_VERSION
#  if !COCOA_Foundation_LIBRARY && !NeXT_Foundation_LIBRARY
#    warning library version not passed in as a default (using 4.5.0)
#  endif
#  define LIBRARY_MAJOR_VERSION 4
#endif
#ifndef LIBRARY_MINOR_VERSION
#  define LIBRARY_MINOR_VERSION 5
#endif
#ifndef LIBRARY_SUBMINOR_VERSION
#  define LIBRARY_SUBMINOR_VERSION 0
#endif

@implementation NGMime

+ (NSString *)libraryVersion {
  static NSString *Version = nil;

  if (Version == nil) {
    Version = [[NSString alloc] initWithFormat:@"NGMime_%d.%d.%d",
                        LIBRARY_MAJOR_VERSION, LIBRARY_MINOR_VERSION,
                        LIBRARY_SUBMINOR_VERSION];
  }
  return Version;
}



- (void)_staticLinkClasses {
}

- (void)_staticLinkModules {
}

@end /* NGMime */
