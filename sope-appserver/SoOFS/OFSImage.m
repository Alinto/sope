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

#include "OFSImage.h"
#include "common.h"

@implementation OFSImage

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    didInit = YES;
    NSAssert2([super version] == 1,
	      @"invalid superclass (%@) version %i !",
	      NSStringFromClass([self superclass]), [super version]);
  }
}

- (void)dealloc {
  [super dealloc];
}

/* operations */

- (NSString *)contentTypeInContext:(WOContext *)_ctx {
  NSString *ext;
  
  ext = [[self storagePath] pathExtension];
  if ([ext isEqualToString:@"gif"])  return @"image/gif";
  if ([ext isEqualToString:@"jpg"])  return @"image/jpeg";
  if ([ext isEqualToString:@"png"])  return @"image/png";
  if ([ext isEqualToString:@"jpeg"]) return @"image/jpeg";
  return @"image/octet-stream";
}

@end /* OFSImage */
