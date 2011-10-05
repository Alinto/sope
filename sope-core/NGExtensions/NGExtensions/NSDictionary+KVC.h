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

#ifndef __NGExtensions_NSDictionary_KVC_H__
#define __NGExtensions_NSDictionary_KVC_H__

#import <Foundation/NSDictionary.h>

@interface NSDictionary(KVC)

- (id)valueForUndefinedKey:(NSString *)key;

- (id)handleQueryWithUnboundKey:(NSString *)key;

- (void)setValue:(id)value forUndefinedKey:(NSString *)key;

- (void)handleTakeValue:(id)value forUnboundKey:(NSString *)key;

@end

#endif /* __NGExtensions_NSDictionary_KVC_H__ */
