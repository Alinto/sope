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

#include "iCalToDo.h"
#include "iCalRecurrenceRule.h"
#include "common.h"

@implementation iCalToDo

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->due             release];
  [self->percentComplete release];
  [self->completed       release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalToDo *new;
  
  new = [super copyWithZone:_zone];
  
  new->due             = [self->due             copyWithZone:_zone];
  new->percentComplete = [self->percentComplete copyWithZone:_zone];
  new->completed       = [self->completed       copyWithZone:_zone];

  return new;
}

/* accessors */

- (void)setPercentComplete:(NSString *)_value {
  ASSIGN(self->percentComplete, _value);
}
- (NSString *)percentComplete {
  return self->percentComplete;
}

- (void)setDue:(NSCalendarDate *)_date {
  ASSIGN(self->due, _date);
}
- (NSCalendarDate *)due {
  return self->due;
}

- (void)setCompleted:(NSCalendarDate *)_date {
  ASSIGN(self->completed, _date);
}
- (NSCalendarDate *)completed {
  return self->completed;
}

/* ical typing */

- (NSString *)entityName {
  return @"vtodo";
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->uid)       [ms appendFormat:@" uid=%@", self->uid];
  if (self->startDate) [ms appendFormat:@" start=%@", self->startDate];
  if (self->due)       [ms appendFormat:@" due=%@", self->due];
  if (self->priority)  [ms appendFormat:@" pri=%@", self->priority];

  if (self->completed) 
    [ms appendFormat:@" completed=%@", self->completed];
  if (self->percentComplete) 
    [ms appendFormat:@" complete=%@", self->percentComplete];
  if (self->accessClass) 
    [ms appendFormat:@" class=%@", self->accessClass];
  
  if (self->summary)
    [ms appendFormat:@" summary=%@", self->summary];

  [ms appendString:@">"];
  return ms;
}

@end /* iCalToDo */
