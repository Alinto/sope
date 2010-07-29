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

#include "iCalFreeBusy.h"
#include "iCalPerson.h"
#include "common.h"

@implementation iCalFreeBusy

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->entries   release];
  [self->organizer release];
  [self->startDate release];
  [self->endDate   release];
  [self->url       release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalFreeBusy *new;
  
  new = [super copyWithZone:_zone];
  
  new->entries   = [self->entries   copyWithZone:_zone];
  new->organizer = [self->organizer copyWithZone:_zone];
  new->startDate = [self->startDate copyWithZone:_zone];
  new->endDate   = [self->endDate   copyWithZone:_zone];
  new->url       = [self->url       copyWithZone:_zone];

  return new;
}

/* accessors */

- (void)setUrl:(NSString *)_url {
  ASSIGN(self->url, _url);
}
- (NSString *)url {
  return self->url;
}

- (void)setStartDate:(NSCalendarDate *)_date {
  ASSIGN(self->startDate, _date);
}
- (NSCalendarDate *)startDate {
  return self->startDate;
}

- (void)setEndDate:(NSCalendarDate *)_date {
  ASSIGN(self->endDate, _date);
}
- (NSCalendarDate *)endDate {
  return self->endDate;
}

- (void)setOrganizer:(iCalPerson *)_organizer {
  ASSIGN(self->organizer, _organizer);
}
- (iCalPerson *)organizer {
  return self->organizer;
}

- (void)addToEntries:(id)_obj {
  if (_obj == nil) return;
  if (self->entries == nil)
    self->entries = [[NSMutableArray alloc] initWithCapacity:1];
  [self->entries addObject:_obj];
}

/* ical typing */

- (NSString *)entityName {
  return @"vfreebusy";
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->startDate) [ms appendFormat:@" from=%@", self->startDate];
  if (self->endDate)   [ms appendFormat:@" to=%@", self->endDate];
  
  if (self->organizer)
    [ms appendFormat:@" organizer=%@", self->organizer];
  
  if ([self->entries count] > 0)
    [ms appendFormat:@" %@", self->entries];
  
  [ms appendString:@">"];
  return ms;
}

@end /* iCalFreeBusy */
