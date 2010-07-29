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

#include "iCalView.h"
#include "iCalPortalUser.h"
#include <NGExtensions/EOCacheDataSource.h>
#include "common.h"

@interface iCalPortalDateFormatter : NSFormatter
{
  iCalView *component;
}

- (id)initWithComponent:(iCalView *)_comp;

@end

@implementation iCalView

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->dateFormatter release];
  [self->dataSource    release];
  [self->item          release];
  [self->calendarName  release];
  [self->today         release];
  [super dealloc];
}

/* accessors */

- (void)setCalendarName:(NSString *)_name {
  ASSIGN(self->calendarName, _name);
}
- (NSString *)calendarName {
  return self->calendarName;
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSTimeZone *)viewTimeZone {
  if ([self hasSession])
    return [[self session] viewTimeZone];
  
  return [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
}

/* datasource */

- (NSString *)entityName {
  return nil;
}

- (EOQualifier *)qualifier {
  return nil;
}

- (EOFetchSpecification *)fetchSpecification {
  EOFetchSpecification *fs;

  fs = [[EOFetchSpecification alloc] init];
  [fs setEntityName:[self entityName]];
  [fs setQualifier:[self qualifier]];
  return [fs autorelease];
}

- (EODataSource *)dataSource {
  EODataSource *ds;
  EOFetchSpecification *fspec;
  
  if (self->dataSource)
    return self->dataSource;
  
  if ((ds = [[self user] dataSourceAtPath:self->calendarName]) == nil)
    return nil;
  
  if ((fspec = [self fetchSpecification]))
    [ds setFetchSpecification:fspec];
  
  if ((ds = [[EOCacheDataSource alloc] initWithDataSource:ds]) == nil)
    return nil;
  
  self->dataSource = ds;
  
  return ds;
}

- (NSFormatter *)dateFormatter {
  if (self->dateFormatter == nil) {
    self->dateFormatter =
      [[iCalPortalDateFormatter alloc] initWithComponent:self];
  }
  return self->dateFormatter;
}

- (NSCalendarDate *)today {
  if (self->today == nil) {
    self->today = [[NSCalendarDate alloc] init];
    [self->today setTimeZone:[self viewTimeZone]];
  }
  return self->today;
}

/* notifications */

- (void)sleep {
  [super sleep];
  [self setItem:nil];
  [self->dataSource    release]; self->dataSource    = nil;
  [self->dateFormatter release]; self->dateFormatter = nil;
}

/* labels */

- (NSString *)localizedTitle {
  NSString *s, *calType;
  NSString *pe;
  
  s  = [self calendarName];
  pe = [s pathExtension];
  s  = [s stringByDeletingPathExtension];

  if ([pe isEqualToString:@"ics"] || [pe length] == 0)
    calType = @"iCalTypeName";
  else if ([pe isEqualToString:@"vfb"] || [pe isEqualToString:@"ifb"])
    calType = @"freeBusyTypeName";
  else
    calType = @"unknownTypeName";
  
  calType = [self stringForKey:calType];
  
  s = [NSString stringWithFormat:@"%@ on %@: %@", 
		  [super localizedTitle], calType, s];
  return s;
}

/* actions */

- (id)run {
  if ([self hasSession]) {
    WORequest *rq;
    id tmp;
  
    rq = [[self context] request];
    
    if ((tmp = [rq formValueForKey:@"calendarName"])) {
      [self setCalendarName:tmp];
    }
    else {
      /* choose default cal ... */
    }
  }  
  return [super run];
}

@end /* iCalView */

@implementation iCalPortalDateFormatter

- (id)initWithComponent:(iCalView *)_comp {
  self->component = _comp;
  return self;
}

- (NSString *)stringForObjectValue:(id)_object {
  static Class NSCalendarDateClass = Nil;

  if (_object == nil) return nil;
  
  if (NSCalendarDateClass == Nil) 
    NSCalendarDateClass = [NSCalendarDateClass class];

  NSLog(@"string for object: %@", _object);
  
  if (![_object isKindOfClass:NSCalendarDateClass])
    return [_object stringValue];
  
  [_object setTimeZone:[self->component viewTimeZone]];
  return [_object descriptionWithCalendarFormat:@"%H:%M"];
}

@end /* iCalPortalDateFormatter */
