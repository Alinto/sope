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

#ifndef __NGExtensions_NSSet_enumerator_H__
#define __NGExtensions_NSSet_enumerator_H__

#import <Foundation/NSSet.h>

@interface NSSet(enumerator)

- (id)initWithObjectsFromEnumerator:(NSEnumerator *)_enumerator;

- (NSArray *)mappedArrayUsingSelector:(SEL)_selector;
- (NSArray *)mappedArrayUsingSelector:(SEL)_selector withObject:(id)_object;
- (NSSet *)mappedSetUsingSelector:(SEL)_selector;
- (NSSet *)mappedSetUsingSelector:(SEL)_selector withObject:(id)_object;

@end

@interface NSMutableSet(enumerator);

- (id)initWithObjectsFromEnumerator:(NSEnumerator *)_enumerator;

@end

#endif /* __NGExtensions_NSSet_enumerator_H__ */
