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

#include "iCalEntityObject.h"
#include "iCalPerson.h"
#include "common.h"

@interface iCalEntityObject (PrivateAPI)
- (NSArray *)_filteredAttendeesThinkingOfPersons:(BOOL)_persons;
@end

@implementation iCalEntityObject

+ (int)version {
  return [super version] + 1 /* v1 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->uid          release];
  [self->summary      release];
  [self->created      release];
  [self->lastModified release];
  [self->startDate    release];
  [self->accessClass  release];
  [self->priority     release];
  [self->alarms       release];
  [self->organizer    release];
  [self->attendees    release];
  [self->comment      release];
  [self->sequence     release];
  [self->location     release];
  [self->status       release];
  [self->categories   release];
  [self->userComment  release];
  [self->url          release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalEntityObject *new;

  new = [super copyWithZone:_zone];

  new->uid          = [self->uid          copyWithZone:_zone];
  new->summary      = [self->summary      copyWithZone:_zone];
  new->timestamp    = self->timestamp;
  new->created      = [self->created      copyWithZone:_zone];
  new->lastModified = [self->lastModified copyWithZone:_zone];
  new->startDate    = [self->startDate    copyWithZone:_zone];
  new->accessClass  = [self->accessClass  copyWithZone:_zone];
  new->priority     = [self->priority     copyWithZone:_zone];
  new->alarms       = [self->alarms       copyWithZone:_zone];
  new->organizer    = [self->organizer    copyWithZone:_zone];
  new->attendees    = [self->attendees    copyWithZone:_zone];
  new->comment      = [self->comment      copyWithZone:_zone];
  new->sequence     = [self->sequence     copyWithZone:_zone];
  new->location     = [self->location     copyWithZone:_zone];
  new->status       = [self->status       copyWithZone:_zone];
  new->categories   = [self->categories   copyWithZone:_zone];
  new->userComment  = [self->userComment  copyWithZone:_zone];
  new->url          = [self->url          copyWithZone:_zone];

  return new;
}

/* accessors */

- (void)setUid:(NSString *)_value {
  if (self->uid != _value) {
    [self->uid autorelease];
    self->uid = [_value retain];
  }
}
- (NSString *)uid {
  return self->uid;
}

- (void)setSummary:(NSString *)_value {
  if (self->summary != _value) {
    [self->summary autorelease];
    self->summary = [_value retain];
  }
}
- (NSString *)summary {
  return self->summary;
}

- (void)setLocation:(NSString *)_value {
  if (self->location != _value) {
    [self->location autorelease];
    self->location = [_value retain];
  }
}
- (NSString *)location {
  return self->location;
}

- (void)setComment:(NSString *)_value {
  if (self->comment != _value) {
    [self->comment autorelease];
    self->comment = [_value retain];
  }
}
- (NSString *)comment {
  return self->comment;
}

- (void)setAccessClass:(NSString *)_value {
  if (self->accessClass != _value) {
    [self->accessClass autorelease];
    self->accessClass = [_value retain];
  }
}
- (NSString *)accessClass {
  return self->accessClass;
}

- (void)setPriority:(NSString *)_value {
  if (self->priority != _value) {
    [self->priority autorelease];
    self->priority = [_value retain];
  }
}
- (NSString *)priority {
  return self->priority;
}

- (void)setCategories:(NSString *)_value {
  ASSIGN(self->categories, _value);
}
- (NSString *)categories {
  return self->categories;
}

- (void)setSequence:(NSNumber *)_value {
  if (![_value isNotNull]) _value = nil;
  if (self->sequence != _value) {
    if (_value != nil && ![_value isKindOfClass:[NSNumber class]])
      _value = [NSNumber numberWithInt:[_value intValue]];
    [self->sequence autorelease];
    self->sequence = [_value retain];
  }
}
- (NSNumber *)sequence {
  return self->sequence;
}
- (void)increaseSequence {
  int seq;
  
  seq = [[self sequence] intValue];
  seq += 1;
  [self setSequence:[NSNumber numberWithInt:seq]];
}

- (void)setStatus:(NSString *)_value {
  ASSIGNCOPY(self->status, _value);
}
- (NSString *)status {
  // eg: STATUS:CONFIRMED
  return self->status;
}

- (void)setCreated:(NSCalendarDate *)_value {
  if (self->created != _value) {
    [self->created autorelease];
    self->created = [_value retain];
  }
}
- (NSCalendarDate *)created {
  return self->created;
}
- (void)setLastModified:(NSCalendarDate *)_value {
  if (self->lastModified != _value) {
    [self->lastModified autorelease];
    self->lastModified = [_value retain];
  }
}
- (NSCalendarDate *)lastModified {
  return self->lastModified;
}

- (void)setTimeStampAsDate:(NSCalendarDate *)_date {
  /* TODO: too be completed */
}
- (NSCalendarDate *)timeStampAsDate {
  return [NSDate dateWithTimeIntervalSince1970:self->timestamp];
}

- (void)setStartDate:(NSCalendarDate *)_date {
  if (self->startDate != _date) {
    [self->startDate autorelease];
    self->startDate = [_date retain];
  }
}
- (NSCalendarDate *)startDate {
  return self->startDate;
}

- (void)setOrganizer:(iCalPerson *)_organizer {
  if (self->organizer != _organizer) {
    [self->organizer autorelease];
    self->organizer = [_organizer retain];
  }
}
- (iCalPerson *)organizer {
  return self->organizer;
}

- (void)removeAllAttendees {
    [self->attendees removeAllObjects];
}
- (void)addToAttendees:(iCalPerson *)_person {
  if (_person == nil) return;
  if (self->attendees == nil)
    self->attendees = [[NSMutableArray alloc] initWithCapacity:4];
  [self->attendees addObject:_person];
}
- (NSArray *)attendees {
  return self->attendees;
}

- (void)removeAllAlarms {
    [self->alarms removeAllObjects];
}
- (void)addToAlarms:(id)_alarm {
  if (_alarm == nil) return;
  if (self->alarms == nil)
    self->alarms = [[NSMutableArray alloc] initWithCapacity:1];
  [self->alarms addObject:_alarm];
}
- (BOOL)hasAlarms {
  return [self->alarms count] > 0 ? YES : NO;
}
- (NSArray *)alarms {
  return self->alarms;
}

- (void)setUserComment:(NSString *)_userComment {
  ASSIGN(self->userComment, _userComment);
}
- (NSString *)userComment {
  return self->userComment;
}

- (void)setUrl:(id)_value {
  if (self->url != _value) {
    [self->url autorelease];
    if ([_value isKindOfClass:[NSString class]]) {
      self->url = [[NSURL alloc] initWithString:_value];
    }
    else {
      self->url = [_value retain];
    }
  }
}
- (NSURL *)url {
  return self->url;
}

/* stuff */

- (NSArray *)participants {
  return [self _filteredAttendeesThinkingOfPersons:YES];
}
- (NSArray *)resources {
  return [self _filteredAttendeesThinkingOfPersons:NO];
}

- (NSArray *)_filteredAttendeesThinkingOfPersons:(BOOL)_persons {
  NSArray        *list;
  NSMutableArray *filtered;
  unsigned       i, count;
  
  list     = [self attendees];
  count    = [list count];
  filtered = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    iCalPerson *p;
    NSString   *role;
    
    p = [list objectAtIndex:i];
    role = [p role];
    if (_persons) {
      if (role == nil || ![role hasPrefix:@"NON-PART"])
        [filtered addObject:p];
    }
    else {
      if ([role hasPrefix:@"NON-PART"])
        [filtered addObject:p];
    }
  }
  return filtered;
}

- (BOOL)isOrganizer:(id)_email {
  _email = [_email lowercaseString];
  return [[[[self organizer] rfc822Email] lowercaseString]
                                          isEqualToString:_email];
}

- (BOOL)isParticipant:(id)_email {
  NSArray *partEmails;
  
  _email     = [_email lowercaseString];
  partEmails = [[self participants] valueForKey:@"rfc822Email"];
  partEmails = [partEmails valueForKey:@"lowercaseString"];
  return [partEmails containsObject:_email];
}

- (iCalPerson *)findParticipantWithEmail:(id)_email {
  NSArray  *ps;
  unsigned i, count;
  
  _email = [_email lowercaseString];
  ps     = [self participants];
  count  = [ps count];

  for (i = 0; i < count; i++) {
    iCalPerson *p;
    
    p = [ps objectAtIndex:i];
    if ([[[p rfc822Email] lowercaseString] isEqualToString:_email])
      return p;
  }
  return nil; /* not found */
}

@end /* iCalEntityObject */
