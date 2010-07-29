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

#ifndef __EOControl_EOKeyGlobalID_H__
#define __EOControl_EOKeyGlobalID_H__

#include <EOControl/EOGlobalID.h>

@class NSArray;

/*
  An immutable global id based on primary key values. The values must
  be passed in the alphabetical order of the attribute named.

  This class cannot be subclassed !!!
*/

@interface EOKeyGlobalID : EOGlobalID < NSCoding >
{
@protected
  NSString     *entityName;
  unsigned int count;
  id           values[1];
}

+ (id)globalIDWithEntityName:(NSString *)_name
  keys:(id *)_keyValues
  keyCount:(unsigned int)_count
  zone:(NSZone *)_zone;

/* accessors */

- (NSString *)entityName;
- (unsigned int)keyCount;
- (id *)keyValues;
- (NSArray *)keyValuesArray;

@end

#endif /* __EOControl_EOKeyGlobalID_H__ */
