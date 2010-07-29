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

#include "iCalCalendar.h"
#include "iCalEvent.h"
#include "iCalToDo.h"
#include "iCalJournal.h"
#include "iCalFreeBusy.h"
#include "iCalEntityObject.h"
#include <SaxObjC/SaxObjC.h>
#include "common.h"

@interface iCalCalendar(Privates)
- (void)addToEvents:(iCalEvent *)_event;
- (void)addToTimezones:(id)_tz;
- (void)addToTodos:(iCalToDo *)_todo;
- (void)addToJournals:(iCalJournal *)_obj;
- (void)addToFreeBusys:(iCalFreeBusy *)_obj;
@end

@implementation iCalCalendar

static id<NSObject,SaxXMLReader> parser  = nil; // THREAD
static SaxObjectDecoder          *sax    = nil; // THREAD

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

+ (id<NSObject,SaxXMLReader>)iCalParser {
  if (sax == nil) {
    sax = [[SaxObjectDecoder alloc] initWithMappingNamed:@"NGiCal"];;
    if (sax == nil) {
      NSLog(@"ERROR(%s): could not create iCal SAX handler!",
	    __PRETTY_FUNCTION__);
    }
  }
  if (sax != nil && parser == nil) {
    parser =
      [[[SaxXMLReaderFactory standardXMLReaderFactory] 
	                     createXMLReaderForMimeType:@"text/calendar"]
                             retain];
    if (parser == nil) {
      NSLog(@"ERROR(%s): did not find a parser for text/calendar!",
	    __PRETTY_FUNCTION__);
      return nil;
    }
    
    [parser setContentHandler:sax];
    [parser setErrorHandler:sax];
  }
  return parser;
}

+ (iCalCalendar *)parseCalendarFromSource:(id)_src {
  static id<NSObject,SaxXMLReader> parser;
  id root, cal;
  
  if ((parser = [self iCalParser]) == nil)
    return nil;
  
  [parser parseFromSource:_src];
  root = [[sax rootObject] retain];
  [sax reset];
  
  if (root == nil)
    return nil;
  if ([root isKindOfClass:self])
    return [root autorelease];
  
  if (![root isKindOfClass:[iCalEntityObject class]]) {
    NSLog(@"ERROR(%s): parsed object is of an unexpected class %@: %@",
	  __PRETTY_FUNCTION__, NSStringFromClass([root class]), root);
    [root release];
    return nil;
  }
  
  /* so we just got an iCalEntityObject, wrap that manually into a cal */
  cal = [[[self alloc] initWithEntityObject:root] autorelease];
  [root release]; root = nil;
  return cal;
}

- (id)initWithEntityObject:(iCalEntityObject *)_entityObject {
  if ((self = [self init])) {
    if ([_entityObject isKindOfClass:[iCalEvent class]])
      [self addToEvents:(iCalEvent *)_entityObject];
    else if ([_entityObject isKindOfClass:[iCalToDo class]])
      [self addToTodos:(iCalToDo *)_entityObject];
    else if ([_entityObject isKindOfClass:[iCalJournal class]])
      [self addToJournals:(iCalJournal *)_entityObject];
    else if ([_entityObject isKindOfClass:[iCalFreeBusy class]])
      [self addToFreeBusys:(iCalFreeBusy *)_entityObject];
    else if ([_entityObject isNotNull]) {
      [self errorWithFormat:@"Unexpected entity object: %@", _entityObject];
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self->version   release];
  [self->calscale  release];
  [self->prodId    release];
  [self->method    release];

  [self->todos     release];
  [self->events    release];
  [self->journals  release];
  [self->freeBusys release];
  [self->timezones release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalCalendar *new;
  
  new = [super copyWithZone:_zone];

  new->version   = [self->version  copyWithZone:_zone];
  new->calscale  = [self->calscale copyWithZone:_zone];
  new->prodId    = [self->prodId   copyWithZone:_zone];
  new->method    = [self->method   copyWithZone:_zone];

  new->todos      = [self->todos     copyWithZone:_zone];
  new->events     = [self->events    copyWithZone:_zone];
  new->journals   = [self->journals  copyWithZone:_zone];
  new->freeBusys  = [self->freeBusys copyWithZone:_zone];
  new->timezones  = [self->timezones copyWithZone:_zone];

  return new;
}

/* accessors */

- (void)setCalscale:(NSString *)_value {
  ASSIGNCOPY(self->calscale, _value);
}
- (NSString *)calscale {
  return self->calscale;
}
- (void)setVersion:(NSString *)_value {
  ASSIGNCOPY(self->version, _value);
}
- (NSString *)version {
  return self->version;
}
- (void)setProdId:(NSString *)_value {
  ASSIGNCOPY(self->prodId, _value);
}
- (NSString *)prodId {
  return self->prodId;
}
- (void)setMethod:(NSString *)_method {
  ASSIGNCOPY(self->method, _method);
}
- (NSString *)method {
  return self->method;
}

- (void)addToEvents:(iCalEvent *)_event {
  if (_event == nil) return;
  if (self->events == nil)
    self->events = [[NSMutableArray alloc] initWithCapacity:4];
  [self->events addObject:_event];
}
- (NSArray *)events {
  return self->events;
}

- (void)addToTimezones:(id)_tz {
  NSString *tzid;
  
  if (_tz == nil) return;
  if (self->timezones == nil)
    self->timezones = [[NSMutableDictionary alloc] initWithCapacity:4];
  
  if ((tzid = [_tz valueForKey:@"tzid"]) == nil) {
    [self logWithFormat:@"ERROR: missing timezone-id in timezone: %@", _tz];
    return;
  }
  [self->timezones setObject:_tz forKey:tzid];
}
- (NSArray *)timezones {
  return [self->timezones allValues];
}

- (void)addToTodos:(iCalToDo *)_todo {
  if (_todo == nil) return;
  if (self->todos == nil)
    self->todos = [[NSMutableArray alloc] initWithCapacity:4];
  [self->todos addObject:_todo];
}
- (NSArray *)todos {
  return self->todos;
}

- (void)addToJournals:(iCalJournal *)_obj {
  if (_obj == nil) return;
  if (self->journals == nil)
    self->journals = [[NSMutableArray alloc] initWithCapacity:4];
  [self->journals addObject:_obj];
}
- (NSArray *)journals {
  return self->journals;
}

- (void)addToFreeBusys:(iCalFreeBusy *)_obj {
  if (_obj == nil) return;
  if (self->freeBusys == nil)
    self->freeBusys = [[NSMutableArray alloc] initWithCapacity:4];
  [self->freeBusys addObject:_obj];
}
- (NSArray *)freeBusys {
  return self->freeBusys;
}

/* collection */

- (NSArray *)allObjects {
  NSMutableArray *ma;
  
  ma = [NSMutableArray arrayWithCapacity:32];
  if (self->events)    [ma addObjectsFromArray:self->events];
  if (self->todos)     [ma addObjectsFromArray:self->todos];
  if (self->freeBusys) [ma addObjectsFromArray:self->freeBusys];
  if (self->journals)  [ma addObjectsFromArray:self->journals];
  return ma;
}
- (NSEnumerator *)objectEnumerator {
  return [[self allObjects] objectEnumerator];
}

/* ical typing */

- (NSString *)entityName {
  return @"vcalendar";
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->version)  [ms appendFormat:@" v%@",         self->version];
  if (self->method)   [ms appendFormat:@" method=%@",   self->method];
  if (self->prodId)   [ms appendFormat:@" product=%@",  self->prodId];
  if (self->calscale) [ms appendFormat:@" calscale=%@", self->calscale];

  if ([self->events count] > 0)
    [ms appendFormat:@" events=%@", self->events];
  if ([self->todos count] > 0)
    [ms appendFormat:@" todos=%@", self->todos];
  if ([self->freeBusys count] > 0)
    [ms appendFormat:@" fb=%@", self->freeBusys];
  if ([self->journals count] > 0)
    [ms appendFormat:@" journals=%@", self->journals];

  if ([self->timezones count] > 0)
    [ms appendFormat:@" tzs=%@", [self->timezones allKeys]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* iCalCalendar */
