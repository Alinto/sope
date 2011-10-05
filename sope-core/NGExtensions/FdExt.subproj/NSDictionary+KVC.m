/*
  Copyright (C) 2000-2008 SKYRIX Software AG

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

#if GNUSTEP_BASE_LIBRARY

#import "common.h"
#import "NSDictionary+KVC.h"

@implementation NSDictionary(KVC)

// TODO: it should be addressed to gnustep-base

- (id)valueForUndefinedKey:(NSString *)key
{
  return nil;
}

- (id)handleQueryWithUnboundKey:(NSString *)key
{
  return nil;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
  return;
}

- (void)handleTakeValue:(id)value forUnboundKey:(NSString *)key
{
  return;
}

@end /* NSDictionary(KVC) */

void __link_NSDictionary_KVC() {
  __link_NSDictionary_KVC();
}

#endif
