/*
 Copyright (C) 2003-2004 Max Berger
 Copyright (C) 2004-2005 OpenGroupware.org

 This file is part of versitSaxDriver, written for the OpenGroupware.org 
 project (OGo).
 
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

#include "VSiCalSaxDriver.h"
#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

@implementation VSiCalSaxDriver

static NSSet   *defElementNames = nil;
static NSArray *defGeoMappings  = nil;

+ (void)initialize {
  static BOOL didInit = NO;

  if(didInit)
    return;
  didInit = YES;

  defElementNames = [[NSSet alloc] initWithObjects:
    @"calscale",
    @"version",
    @"prodid",
    @"method",
    nil];
  defGeoMappings = [[NSArray alloc] initWithObjects:
    @"lat",
    @"lon",
    nil];
}

+ (NSDictionary *)xcalMapping  {
  static NSDictionary *dict = nil;
  if (dict == nil) {
    NSMutableDictionary *xcal;

    xcal = [[NSMutableDictionary alloc] initWithCapacity:60];
    /* 
      +---------------+-----------+-----------+-----------------+
     | Calendar      | Attribute | Attribute | Default         |
     | Property Name | Name      | Type      | Value           |
     +---------------+-----------+-----------+-----------------+
     | CALSCALE      | calscale  | CDATA     | IMPLIED         |
     | METHOD        | method    | NMTOKEN   | PUBLISH         |
     | VERSION       | version   | CDATA     | REQUIRED        |
     | PRODID        | prodid    | CDATA     | IMPLIED         |
     +---------------+-----------+-----------+-----------------+
      */
    [xcal setObject:@"calscale" forKey:@"CALSCALE"];
    [xcal setObject:@"method" forKey:@"METHOD"];
    [xcal setObject:@"version" forKey:@"VERSION"];
    [xcal setObject:@"prodid" forKey:@"PRODID"];
    
    /*
     Descriptive Component Properties
     +----------------+-------------+-----------------------------+
     | Component      | Element     | Element Content Model       |
     | Property Name  | Name        |                             |
     +----------------+-------------+-----------------------------+
     | ATTACH         | attach      | extref or b64bin            |
     |                | extref      | EMPTY                       |
     |                | b64bin      | PCDATA                      |
     | CATEGORIES     | categories  | Any number of item elements |
     |                | item        | PCDATA                      |
     | CLASS          | class       | PCDATA                      |
     | COMMENT        | comment     | PCDATA                      |
     | DESCRIPTION    | description | PCDATA                      |
     | GEO            | geo         | lat followed by lon element |
     |                | lat         | PCDATA                      |
     |                | lon         | PCDATA                      |
     | LOCATION       | location    | PCDATA                      |
     | PERCENT        | percent     | PCDATA                      |
     | PRIORITY       | priority    | PCDATA                      |
     | RESOURCES      | resources   | Any number of item elements |
     | STATUS         | status      | PCDATA                      |
     | SUMMARY        | summary     | PCDATA                      |
     +----------------+-------------+-----------------------------+
     */
    
    [xcal setObject:@"attach" forKey:@"ATTACH"];
    [xcal setObject:@"categories" forKey:@"CATEGORIES"];
    [xcal setObject:@"class" forKey:@"CLASS"];
    [xcal setObject:@"comment" forKey:@"COMMENT"];
    [xcal setObject:@"description" forKey:@"DESCRIPTION"];
    [xcal setObject:@"geo" forKey:@"GEO"];
    [xcal setObject:@"location" forKey:@"LOCATION"];
    [xcal setObject:@"percent" forKey:@"PERCENT"];
    [xcal setObject:@"priority" forKey:@"PRIORITY"];
    [xcal setObject:@"resources" forKey:@"RESOURCES"];
    [xcal setObject:@"status" forKey:@"STATUS"];
    [xcal setObject:@"summary" forKey:@"SUMMARY"];
      
    /*
     Date and Time Component Properties
     +----------------+------------+-----------------------------+
     | Component      | Element    | Element Content Model       |
     | Property Name  | Name       |                             |
     +----------------+------------+-----------------------------+
     | COMPLETED      | completed  | PCDATA                      |
     | DTEND          | dtend      | PCDATA                      |
     | DUE            | due        | PCDATA                      |
     | DTSTART        | dtstart    | PCDATA                      |
     | DURATION       | duration   | PCDATA                      |
     | FREEBUSY       | freebusy   | PCDATA                      |
     | TRANSP         | transp     | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    
    [xcal setObject:@"completed" forKey:@"COMPLETED"];
    [xcal setObject:@"dtend" forKey:@"DTEND"];
    [xcal setObject:@"due" forKey:@"DUE"];
    [xcal setObject:@"dtstart" forKey:@"DTSTART"];
    [xcal setObject:@"duration" forKey:@"DURATION"];
    [xcal setObject:@"freebusy" forKey:@"FREEBUSY"];
    [xcal setObject:@"transp" forKey:@"TRANSP"];    
    
    /*
     Time Zone Component Properties
     +----------------+-------------+-----------------------------+
     | Component      | Element     | Element Content Model       |
     | Property Name  | Name        |                             |
     +----------------+-------------+-----------------------------+
     | TZID           | tzid        | PCDATA                      |
     | TZNAME         | tzname      | PCDATA                      |
     | TZOFFSETFROM   | tzoffsetfrom| PCDATA                      |
     | TZOFFSETTO     | tzoffsetto  | PCDATA                      |
     | TZURL          | tzurl       | EMPTY                       |
     +----------------+-------------+-----------------------------+     
     */
    
    [xcal setObject:@"tzid" forKey:@"TZID"];
    [xcal setObject:@"tzname" forKey:@"TZNAME"];
    [xcal setObject:@"tzoffsetfrom" forKey:@"TZOFFSETFROM"];
    [xcal setObject:@"tzoffsetto" forKey:@"TZOFFSETTO"];
    [xcal setObject:@"tzurl" forKey:@"TZURL"];
    
    /*    
     Relationship Component Properties
     +----------------+---------------+--------------------------+
     | Component      | Element       | Element Content Model    |
     | Property Name  | Name          |                          |
     +----------------+---------------+--------------------------+
     | ATTENDEE       | attendee      | PCDATA                   |
     | CONTACT        | contact       | PCDATA                   |
     | ORGANIZER      | organizer     | PCDATA                   |
     | RECURRENCE-ID  | recurrence-id | PCDATA                   |
     | RELATED-TO     | related-to    | PCDATA                   |
     | URL            | url           | EMPTY                    |
     | UID            | uid           | PCDATA                   |
     +----------------+---------------+--------------------------+
    */ 
    [xcal setObject:@"attendee" forKey:@"ATTENDEE"];
    [xcal setObject:@"contact" forKey:@"CONTACT"];
    [xcal setObject:@"organizer" forKey:@"ORGANIZER"];
    [xcal setObject:@"recurrence-id" forKey:@"RECURRENCE-ID"];
    [xcal setObject:@"related-to" forKey:@"RELATED-TO"];
    [xcal setObject:@"url" forKey:@"URL"];
    [xcal setObject:@"uid" forKey:@"UID"];
    
    /*
     Recurrence Component Properties
     +----------------+------------+-----------------------------+
     | Component      | Element    | Element Content Model       |
     | Property Name  | Name       |                             |
     +----------------+------------+-----------------------------+
     | EXDATE         | exdate     | PCDATA                      |
     | EXRULE         | exrule     | PCDATA                      |
     | RDATE          | rdate      | PCDATA                      |
     | RRULE          | rrule      | PCDATA                      |
     +----------------+------------+-----------------------------+
     
     */
    [xcal setObject:@"exdate" forKey:@"EXDATE"];
    [xcal setObject:@"exrule" forKey:@"EXRULE"];
    [xcal setObject:@"rdate" forKey:@"RDATE"];
    [xcal setObject:@"rrule" forKey:@"RRULE"];
    
    /*     
     Alarm Component Properties
     +----------------+------------+-----------------------------+
     | Component      | Element    | Element Content Model       |
     | Property Name  | Name       |                             |
     +----------------+------------+-----------------------------+
     | ACTION         | action     | PCDATA                      |
     | REPEAT         | repeat     | PCDATA                      |
     | TRIGGER        | trigger    | PCDATA                      |
     +----------------+------------+-----------------------------+
     */
    [xcal setObject:@"action" forKey:@"ACTION"];
    [xcal setObject:@"repeat" forKey:@"REPEAT"];
    [xcal setObject:@"trigger" forKey:@"TRIGGER"];
    
    /* 
     Change Management Component Properties
     +----------------+---------------+--------------------------+
     | Component      | Element       | Element Content Model    |
     | Property Name  | Name          |                          |
     +----------------+---------------+--------------------------+
     | CREATED        | created       | PCDATA                   |
     | DTSTAMP        | dtstamp       | PCDATA                   |
     | LAST-MODIFIED  | last-modified | PCDATA                   |
     | SEQUENCE       | sequence      | PCDATA                   |
     +----------------+---------------+--------------------------+
     */
    [xcal setObject:@"created" forKey:@"CREATED"];
    [xcal setObject:@"dtstamp" forKey:@"DTSTAMP"];
    [xcal setObject:@"last-modified" forKey:@"LAST-MODIFIED"];
    [xcal setObject:@"sequence" forKey:@"SEQUENCE"];
    
     /*
     Miscellaneous Component Properties
     +----------------+----------------+-------------------------+
     | Component      | Element        | Element Content Model   |
     | Property Name  | Name           |                         |
     +----------------+----------------+-------------------------+
     | REQUEST-STATUS | request-status | PCDATA                  |
     +----------------+----------------+-------------------------+
     */
    [xcal setObject:@"request-status" forKey:@"REQUEST-STATUS"];

    
    /*
     Component Structuring Properties
     +----------------+------------+-------------------------------+
     | Component      | Element    | Element Content Model         |
     | Property Name  | Name       |                               |
     +----------------+------------+-------------------------------+
     | Multiple iCal- | iCalendar  | One or more iCal elements     |
     | endar objects  |            |                               |
     | VCALENDAR      | vcalendar  | calcomp parameter entity      |
     | VEVENT         | vevent     | vevent.opt1 and vevent.optm   |
     |                |            | parameter entity and valarm   |
     |                |            | element                       |
     | VTODO          | vtodo      | vtodo.opt1 and vtodo.optm     |
     |                |            | parameter entity and valarm   |
     |                |            | element                       |
     | VJOURNAL       | vjournal   | vjournal.opt1 and             |
     |                |            | vjournal.optm parameter       |
     |                |            | entity                        |
     | VFREEBUSY      | vfreebusy  | vfreebusy.opt1 and            |
     |                |            | vfreebusy.optm parameter      |
     |                |            | entity                        |
     | VTIMEZONE      | vtimezone  | vtimezone.man,                |
     |                |            | vtimezone.opt1,               |
     |                |            | vtimezone.mann parameter      |
     |                |            | entity                        |
     | STANDARD       | standard   | standard.man or standard.optm |
     |                |            | entity                        |
     | DAYLIGHT       | daylight   | daylight.man or daylight.optm |
     |                |            | entity                        |
     | VALARM         | valarm     | valarm.audio, valarm.display, |
     |                |            | valarm.email and              |
     |                |            | valarm.procedure entity       |
     +----------------+------------+-------------------------------+
     */

    [xcal setObject:@"vcalendar" forKey:@"VCALENDAR"];
    [xcal setObject:@"vevent" forKey:@"VEVENT"];
    [xcal setObject:@"vtodo" forKey:@"VTODO"];
    [xcal setObject:@"vjournal" forKey:@"VJOURNAL"];
    [xcal setObject:@"vfreebusy" forKey:@"VFREEBUSY"];
    [xcal setObject:@"vtimezone" forKey:@"VTIMEZONE"];
    [xcal setObject:@"standard" forKey:@"STANDARD"];
    [xcal setObject:@"daylight" forKey:@"DAYLIGHT"];
    [xcal setObject:@"valarm" forKey:@"VALARM"];
    
    dict = [xcal copy];
    [xcal release];
  }
  return dict;
}

+ (NSDictionary *)xcalAttrMapping {
  static NSDictionary *dict = nil;
  if (dict == nil) {
    NSMutableDictionary *xcal;

    xcal = [[NSMutableDictionary alloc] initWithCapacity:20];
    /*
     ----------------+----------------+-----------+-----------------+
     | Property       | Attribute      | Attribute | Default         |
     | Parameter Name | Name           | Type      | Value           |
     +----------------+----------------+-----------+-----------------+
     | ALTREP         | altrep         | ENTITY    | IMPLIED         |
     | CN             | cn             | CDATA     | Null String     |
     | CUTYPE         | cutype         | NMTOKEN   | INDIVIDUAL      |
     | DELEGATED-FROM | delegated-from | CDATA     | IMPLIED         |
     | DELEGATED-TO   | delegated-to   | CDATA     | IMPLIED         |
     | DIR            | dir            | ENTITY    | IMPLIED         |
     | ENCODING       | Not Used       | n/a       | n/a             |
     | FMTTYPE        | fmttype        | CDATA     | REQUIRED        |
     | FBTYPE         | fbtype         | NMTOKEN   | BUSY            |
     | LANGUAGE       | language       | CDATA     | IMPLIED         |
     | MEMBER         | member         | CDATA     | IMPLIED         |
     | PARTSTAT       | partstat       | NMTOKEN   | NEEDS-ACTION    |
     | RANGE          | range          | NMTOKEN   | THISONLY        |
     | RELATED        | related        | NMTOKEN   | START           |
     | RELTYPE        | reltype        | NMTOKEN   | PARENT          |
     | ROLE           | role           | NMTOKEN   | REQ-PARTICIPANT |
     | RSVP           | rsvp           | NMTOKEN   | FALSE           |
     | SENT-BY        | sent-by        | CDATA     | IMPLIED         |
     | TZID           | tzid           | CDATA     | IMPLIED         |
     | VALUE          | value          | NOTATION  | See elements    |
     +----------------+----------------+-----------+-----------------+
     */
    [xcal setObject:@"altrep" forKey:@"ALTREP"];
    [xcal setObject:@"cn" forKey:@"CN"];
    [xcal setObject:@"cutype" forKey:@"CUTYPE"];
    [xcal setObject:@"delegated-from" forKey:@"DELEGATED-FROM"];
    [xcal setObject:@"delegated-to" forKey:@"DELEGATED-TO"];
    [xcal setObject:@"dir" forKey:@"DIR"];
    [xcal setObject:@"Not" forKey:@"ENCODING"];
    [xcal setObject:@"fmttype" forKey:@"FMTTYPE"];
    [xcal setObject:@"fbtype" forKey:@"FBTYPE"];
    [xcal setObject:@"language" forKey:@"LANGUAGE"];
    [xcal setObject:@"member" forKey:@"MEMBER"];
    [xcal setObject:@"partstat" forKey:@"PARTSTAT"];
    [xcal setObject:@"range" forKey:@"RANGE"];
    [xcal setObject:@"related" forKey:@"RELATED"];
    [xcal setObject:@"reltype" forKey:@"RELTYPE"];
    [xcal setObject:@"role" forKey:@"ROLE"];
    [xcal setObject:@"rsvp" forKey:@"RSVP"];
    [xcal setObject:@"sent-by" forKey:@"SENT-BY"];
    [xcal setObject:@"tzid" forKey:@"TZID"];
    [xcal setObject:@"value" forKey:@"VALUE"];
    
    dict = [xcal copy];
    [xcal release];
  }
  return dict;
}

- (id)init {
  if ((self = [super init])) {
    [self setPrefixURI:XMLNS_XCAL_01];
    [self setElementMapping:[[self class] xcalMapping]];
    [self setAttributeElements:defElementNames];

    [self setAttributeMapping:[[self class] xcalAttrMapping]];
    [self setSubItemMapping:defGeoMappings forElement:@"geo"];
  }
  return self;
}

@end /* ICalendarSaxDriver */
