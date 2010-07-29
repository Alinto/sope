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

#ifndef __NGExtensions_NGMerging_H__
#define __NGExtensions_NGMerging_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSZone.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>

@interface NSObject(NGMerging)

- (BOOL)canMergeWithObject:(id)_object;
- (id)mergeWithObject:(id)_object zone:(NSZone *)_zone;
- (id)mergeWithObject:(id)_object;

@end

/*
  dictionaries merge only with other dictionaries
*/
@interface NSDictionary(NGMerging)

- (id)mergeWithDictionary:(NSDictionary *)_object zone:(NSZone *)_zone;

@end

/*
  arrays merge with any objects responding to -objectEnumerator
*/
@interface NSArray(NGMerging)

- (id)mergeWithArray:(NSArray *)_object zone:(NSZone *)_zone;
- (id)mergeWithEnumeration:(NSEnumerator *)_object zone:(NSZone *)_zone;

@end

#endif /* __NGExtensions_NGMerging_H__ */
