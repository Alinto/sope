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

#ifndef __NGiCal_iCalCalendar_H__
#define __NGiCal_iCalCalendar_H__

#include <NGiCal/iCalObject.h>

@class NSString, NSMutableArray, NSArray, NSEnumerator, NSMutableDictionary;
@class iCalEvent, iCalToDo, iCalJournal, iCalFreeBusy, iCalEntityObject;

@interface iCalCalendar : iCalObject
{
  NSString *version;
  NSString *calscale;
  NSString *prodId;
  NSString *method;

  NSMutableArray *todos;
  NSMutableArray *events;
  NSMutableArray *journals;
  NSMutableArray *freeBusys;
  NSMutableDictionary *timezones;
}

+ (iCalCalendar *)parseCalendarFromSource:(id)_src;
- (id)initWithEntityObject:(iCalEntityObject *)_entityObject;

/* accessors */

- (NSString *)calscale;
- (NSString *)version;
- (NSString *)prodId;
- (NSString *)method;

- (NSArray *)events;
- (NSArray *)todos;
- (NSArray *)journals;
- (NSArray *)freeBusys;

/* collection */

- (NSArray *)allObjects;
- (NSEnumerator *)objectEnumerator;

@end

#endif /* __NGiCal_iCalCalendar_H__ */
