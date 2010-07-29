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

#ifndef __NGiCal_iCalEntityObject_H__
#define __NGiCal_iCalEntityObject_H__

#include <NGiCal/iCalObject.h>

/*
  iCalEntityObject
  
  This is a common base class for tasks and appointments which share a lot of
  attributes.
*/

@class NSCalendarDate, NSMutableArray, NSString, NSArray, NSNumber;
@class iCalPerson;
@class NSURL;

@interface iCalEntityObject : iCalObject
{
  NSString       *uid;
  NSString       *summary;
  NSTimeInterval timestamp;
  NSCalendarDate *created;
  NSCalendarDate *lastModified;
  NSCalendarDate *startDate;
  NSString       *accessClass;
  NSString       *priority;
  NSMutableArray *alarms;
  iCalPerson     *organizer;
  NSMutableArray *attendees;
  NSString       *comment;
  NSNumber       *sequence;
  NSString       *location;
  NSString       *status;
  NSString       *categories;
  NSString       *userComment;
  NSURL          *url;
}

/* accessors */

- (void)setUid:(NSString *)_value;
- (NSString *)uid;

- (void)setSummary:(NSString *)_value;
- (NSString *)summary;

- (void)setLocation:(NSString *)_value;
- (NSString *)location;

- (void)setComment:(NSString *)_value;
- (NSString *)comment;

- (void)setTimeStampAsDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)timeStampAsDate;

- (void)setStartDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)startDate;

- (void)setLastModified:(NSCalendarDate *)_value;
- (NSCalendarDate *)lastModified;

- (void)setCreated:(NSCalendarDate *)_value;
- (NSCalendarDate *)created;

- (void)setAccessClass:(NSString *)_value;
- (NSString *)accessClass;

- (void)setPriority:(NSString *)_value;
- (NSString *)priority;

- (void)setCategories:(NSString *)_value;
- (NSString *)categories;

- (void)setSequence:(NSNumber *)_value; /* this is an int */
- (NSNumber *)sequence;
- (void)increaseSequence;

- (void)setUserComment:(NSString *)_userComment;
- (NSString *)userComment;

/* url can either be set as NSString or NSURL */ 
- (void)setUrl:(id)_value;
- (NSURL *)url;
  
- (void)setOrganizer:(iCalPerson *)_organizer;
- (iCalPerson *)organizer;
- (BOOL)isOrganizer:(id)_email;

- (void)setStatus:(NSString *)_value;
- (NSString *)status;

- (void)removeAllAttendees;
- (void)addToAttendees:(iCalPerson *)_person;
- (NSArray *)attendees;

/* categorize attendees into participants and resources */
- (NSArray *)participants;
- (NSArray *)resources;
- (BOOL)isParticipant:(id)_email;
- (iCalPerson *)findParticipantWithEmail:(id)_email;
  
- (void)removeAllAlarms;
- (void)addToAlarms:(id)_alarm;
- (NSArray *)alarms;
- (BOOL)hasAlarms;

@end

#endif /* __NGiCal_iCalEntityObject_H__ */
