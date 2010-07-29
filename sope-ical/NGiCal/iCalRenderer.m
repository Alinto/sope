/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "iCalRenderer.h"
#include "iCalEvent.h"
#include "iCalPerson.h"
#include "iCalRecurrenceRule.h"
#include "NSCalendarDate+ICal.h"
#include "common.h"

@implementation iCalRenderer

static iCalRenderer *renderer = nil;

/* assume length of 1K - reasonable ? */
static unsigned DefaultICalStringCapacity = 1024;

+ (id)sharedICalendarRenderer {
  if (renderer == nil)
    renderer = [[self alloc] init];
  return renderer;
}

/* renderer */

- (void)addPreambleForAppointment:(iCalEvent *)_apt
  toString:(NSMutableString *)s
{
  [s appendString:@"BEGIN:VCALENDAR\r\nMETHOD:REQUEST\r\n"];
  [s appendFormat:@"PRODID:NGiCal/%i.%i\r\n",
       SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
  [s appendString:@"VERSION:2.0\r\n"];
}
- (void)addPostambleForAppointment:(iCalEvent *)_apt
  toString:(NSMutableString *)s
{
  [s appendString:@"END:VCALENDAR\r\n"];
}

- (void)addOrganizer:(iCalPerson *)p toString:(NSMutableString *)s {
  NSString *x;
  
  if (![p isNotNull]) return;
  
  [s appendString:@"ORGANIZER;CN=\""];
  if ((x = [p cn]))
    [s appendString:[x iCalDQUOTESafeString]];
  
  [s appendString:@"\""];
  if ((x = [p email])) {
    [s appendString:@":"]; /* sic! */
    [s appendString:[x iCalSafeString]];
  }
  [s appendString:@"\r\n"];
}

- (void)addAttendees:(NSArray *)persons toString:(NSMutableString *)s {
  unsigned   i, count;
  iCalPerson *p;

  count   = [persons count];
  for (i = 0; i < count; i++) {
    NSString *x;
    
    p = [persons objectAtIndex:i];
    [s appendString:@"ATTENDEE;"];
    
    if ((x = [p role])) {
      [s appendString:@"ROLE="];
      [s appendString:[x iCalSafeString]];
      [s appendString:@";"];
    }
    
    if ((x = [p partStat])) {
      if ([p participationStatus] != iCalPersonPartStatNeedsAction) {
        [s appendString:@"PARTSTAT="];
        [s appendString:[x iCalSafeString]];
        [s appendString:@";"];
      }
    }

    [s appendString:@"CN=\""];
    if ((x = [p cnWithoutQuotes])) {
      [s appendString:[x iCalDQUOTESafeString]];
    }
    [s appendString:@"\""];
    if ([(x = [p email]) isNotNull]) {
      [s appendString:@":"]; /* sic! */
      [s appendString:[x iCalSafeString]];
    }
    [s appendString:@"\r\n"];
  }
}

- (void)addVEventForAppointment:(iCalEvent *)event
  toString:(NSMutableString *)s
{
  id tmp;
  
  [s appendString:@"BEGIN:VEVENT\r\n"];
  
  [s appendString:@"SUMMARY:"];
  [s appendString:[[event summary] iCalSafeString]];
  [s appendString:@"\r\n"];
  if ([[event location] length] > 0) {
    [s appendString:@"LOCATION:"];
    [s appendString:[[event location] iCalSafeString]];
    [s appendString:@"\r\n"];
  }
  
  if ((tmp = [event uid]) != nil) {
    [s appendString:@"UID:"];
    [s appendString:tmp];
    [s appendString:@"\r\n"];
  }
  
  [s appendString:@"DTSTART:"];
  [s appendString:[[event startDate] icalString]];
  [s appendString:@"\r\n"];
  
  if ([event hasEndDate]) {
    [s appendString:@"DTEND:"];
    [s appendString:[[event endDate] icalString]];
    [s appendString:@"\r\n"];
  }
  if ([event hasDuration]) {
    [s appendString:@"DURATION:"];
    [s appendString:[event duration]];
    [s appendString:@"\r\n"];
  }
  if ([[event priority] length] > 0) {
    [s appendString:@"PRIORITY:"];
    [s appendString:[event priority]];
    [s appendString:@"\r\n"];
  }
  if ([[event categories] length] > 0) {
    NSString *catString;
    
    catString = [event categories];
    [s appendString:@"CATEGORIES:"];
    [s appendString:catString];
    [s appendString:@"\r\n"];
  }
  if ([[event comment] length] > 0) {
    [s appendString:@"DESCRIPTION:"]; /* this is what iCal.app does */
    [s appendString:[[event comment] iCalSafeString]];
    [s appendString:@"\r\n"];
  }

  if ((tmp = [event status]) != nil) {
    [s appendString:@"STATUS:"];
    [s appendString:tmp];
    [s appendString:@"\r\n"];
  }

  if ((tmp = [event transparency]) != nil) {
    [s appendString:@"TRANSP:"];
    [s appendString:tmp];
    [s appendString:@"\r\n"];
  }

  [s appendString:@"CLASS:"];
  [s appendString:[event accessClass]];
  [s appendString:@"\r\n"];

  /* recurrence rules */
  if ([event hasRecurrenceRules]) {
    NSArray  *rules;
    unsigned i, count;
    
    rules = [event recurrenceRules];
    count = [rules count];
    for (i = 0; i < count; i++) {
      iCalRecurrenceRule *rule;
      
      rule = [rules objectAtIndex:i];
      [s appendString:@"RRULE:"];
      [s appendString:[rule iCalRepresentation]];
      [s appendString:@"\r\n"];
    }
  }

  /* exception rules */
  if ([event hasExceptionRules]) {
    NSArray  *rules;
    unsigned i, count;
    
    rules = [event exceptionRules];
    count = [rules count];
    for (i = 0; i < count; i++) {
      iCalRecurrenceRule *rule;
      
      rule = [rules objectAtIndex:i];
      [s appendString:@"EXRULE:"];
      [s appendString:[rule iCalRepresentation]];
      [s appendString:@"\r\n"];
    }
  }

  /* exception dates */
  if ([event hasExceptionDates]) {
    NSArray *dates;
    unsigned i, count;
    
    dates = [event exceptionDates];
    count = [dates count];
    [s appendString:@"EXDATE:"];
    for (i = 0; i < count; i++) {
      if (i > 0)
        [s appendString:@","];
      [s appendString:[[dates objectAtIndex:i] icalString]];
    }
    [s appendString:@"\r\n"];
  }

  [self addOrganizer:[event organizer] toString:s];
  [self addAttendees:[event attendees] toString:s];
  
  /* postamble */
  [s appendString:@"END:VEVENT\r\n"];
}

- (BOOL)isValidAppointment:(iCalEvent *)_apt {
  if (![_apt isNotNull])
    return NO;
  
  if ([[_apt uid] length] == 0) {
    [self warnWithFormat:@"got apt without uid, rejecting iCal generation: %@", 
                           _apt];
    return NO;
  }
  if ([[[_apt startDate] icalString] length] == 0) {
    [self warnWithFormat:@"got apt without start date, "
	                       @"rejecting iCal generation: %@",
	                         _apt];
    return NO;
  }
  
  return YES;
}

- (NSString *)vEventStringForEvent:(iCalEvent *)_apt {
  NSMutableString *s;
  
  if (![self isValidAppointment:_apt])
    return nil;
  
  s = [NSMutableString stringWithCapacity:DefaultICalStringCapacity];
  [self addVEventForAppointment:_apt toString:s];
  return s;
}

- (NSString *)iCalendarStringForEvent:(iCalEvent *)_apt {
  NSMutableString *s;
  
  if (![self isValidAppointment:_apt])
    return nil;
  
  s = [NSMutableString stringWithCapacity:DefaultICalStringCapacity];
  [self addPreambleForAppointment:_apt  toString:s];
  [self addVEventForAppointment:_apt    toString:s];
  [self addPostambleForAppointment:_apt toString:s];
  return s;
}

@end /* iCalRenderer */

@interface NSString (SOGoiCal_Private)
- (NSString *)iCalCleanString;
@end

@interface SOGoICalStringEscaper : NSObject <NGStringEscaping>
{
}
+ (id)sharedEscaper;
@end

@implementation SOGoICalStringEscaper
+ (id)sharedEscaper {
  static id sharedInstance = nil;
  if (!sharedInstance) {
    sharedInstance = [[self alloc] init];
  }
  return sharedInstance;
}

- (NSString *)stringByEscapingString:(NSString *)_s {
  unichar c;

  if (!_s || [_s length] == 0)
    return nil;

  c = [_s characterAtIndex:0];
  if (c == '\n') {
    return @"\\n";
  }
  else if (c == '\r') {
    return nil; /* effectively remove char */
  }
  return [NSString stringWithFormat:@"\\%@", _s];
}

@end

@implementation NSString (SOGoiCal)

#if 0
- (NSString *)iCalFoldedString {
  /* RFC2445, 4.1 Content Lines
  
  The iCalendar object is organized into individual lines of text,
  called content lines. Content lines are delimited by a line break,
  which is a CRLF sequence (US-ASCII decimal 13, followed by US-ASCII
                            decimal 10).
  Lines of text SHOULD NOT be longer than 75 octets, excluding the line
  break. Long content lines SHOULD be split into a multiple line
  representations using a line "folding" technique. That is, a long
  line can be split between any two characters by inserting a CRLF
  immediately followed by a single linear white space character (i.e.,
  SPACE, US-ASCII decimal 32 or HTAB, US-ASCII decimal 9).
  Any sequence of CRLF followed immediately by a single linear white space
  character is ignored (i.e., removed) when processing the content type.
  */
}
#endif

/* strip off any characters from string which are not allowed in iCal */
- (NSString *)iCalCleanString {
  static NSCharacterSet *replaceSet = nil;

  if (replaceSet == nil) {
    replaceSet = [NSCharacterSet characterSetWithCharactersInString:@"\r"];
    [replaceSet retain];
  }
  
  return [self stringByEscapingCharactersFromSet:replaceSet
               usingStringEscaping:[SOGoICalStringEscaper sharedEscaper]];
}

- (NSString *)iCalDQUOTESafeString {
  static NSCharacterSet *escapeSet = nil;
  
  if (escapeSet == nil) {
    escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"\\\""];
    [escapeSet retain];
  }
  return [self iCalEscapedStringWithEscapeSet:escapeSet];
}

- (NSString *)iCalSafeString {
  static NSCharacterSet *escapeSet = nil;
  
  if (escapeSet == nil) {
    escapeSet = 
      [[NSCharacterSet characterSetWithCharactersInString:@"\n,;\\\""] retain];
  }
  return [self iCalEscapedStringWithEscapeSet:escapeSet];
}

/* Escape unsafe characters */
- (NSString *)iCalEscapedStringWithEscapeSet:(NSCharacterSet *)_es {
  NSString *s;

  s = [self iCalCleanString];
  return [s stringByEscapingCharactersFromSet:_es
            usingStringEscaping:[SOGoICalStringEscaper sharedEscaper]];
}

@end /* NSString (SOGoiCal) */
