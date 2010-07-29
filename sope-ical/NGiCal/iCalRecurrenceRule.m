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

#include "iCalRecurrenceRule.h"
#include "NSCalendarDate+ICal.h"
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

/*
  freq       = rrFreq;
  until      = rrUntil;
  count      = rrCount;
  interval   = rrInterval;
  bysecond   = rrBySecondList;
  byminute   = rrByMinuteList;
  byhour     = rrByHourList;
  byday      = rrByDayList;
  bymonthday = rrByMonthDayList;
  byyearday  = rrByYearDayList;
  byweekno   = rrByWeekNumberList;
  bymonth    = rrByMonthList;
  bysetpos   = rrBySetPosList;
  wkst       = rrWeekStart;
*/

// TODO: private API in the header file?!
@interface iCalRecurrenceRule (PrivateAPI)

- (iCalWeekDay)weekDayFromICalRepresentation:(NSString *)_day;
- (NSString *)iCalRepresentationForWeekDay:(iCalWeekDay)_weekDay;
- (NSString *)freq;
- (NSString *)wkst;
- (NSString *)byDayList;

- (void)_parseRuleString:(NSString *)_rrule;
- (void)setRrule:(NSString *)_rrule; // TODO: weird name?

/* currently used by parser, should be removed (replace with an -init..) */
- (void)setByday:(NSString *)_byDayList;
- (void)setFreq:(NSString *)_freq;

@end

@implementation iCalRecurrenceRule

+ (id)recurrenceRuleWithICalRepresentation:(NSString *)_iCalRep {
  return [[[self alloc] initWithString:_iCalRep] autorelease];
}

- (id)init { /* designated initializer */
  if ((self = [super init]) != nil) {
    self->byDay.weekStart = iCalWeekDayMonday;
    self->interval        = 1;
  }
  return self;
}

- (id)initWithString:(NSString *)_str {
  if ((self = [self init]) != nil) {
    [self setRrule:_str];
  }
  return self;
}

- (void)dealloc {
  [self->byMonthDay release];
  [self->untilDate  release];
  [self->rrule      release];
  [super dealloc];
}


/* accessors */

- (void)setFrequency:(iCalRecurrenceFrequency)_frequency {
  self->frequency = _frequency;
}
- (iCalRecurrenceFrequency)frequency {
  return self->frequency;
}

- (void)setRepeatCount:(unsigned)_repeatCount {
  self->repeatCount = _repeatCount;
}
- (unsigned)repeatCount {
  return self->repeatCount;
}

- (void)setUntilDate:(NSCalendarDate *)_untilDate {
  ASSIGNCOPY(self->untilDate, _untilDate);
}
- (NSCalendarDate *)untilDate {
  return self->untilDate;
}

- (void)setRepeatInterval:(int)_repeatInterval {
  self->interval = _repeatInterval;
}
- (int)repeatInterval {
  return self->interval;
}

- (void)setWeekStart:(iCalWeekDay)_weekStart {
  self->byDay.weekStart = _weekStart;
}
- (iCalWeekDay)weekStart {
  return self->byDay.weekStart;
}

- (void)setByDayMask:(unsigned)_mask {
  self->byDay.mask = _mask;
}
- (unsigned)byDayMask {
  return self->byDay.mask;
}
- (int)byDayOccurence1 {
  return self->byDayOccurence1;
}

- (NSArray *)byMonthDay {
  return self->byMonthDay;
}

- (BOOL)isInfinite {
  return (self->repeatCount != 0 || self->untilDate) ? NO : YES;
}


/* private */

- (iCalWeekDay)weekDayFromICalRepresentation:(NSString *)_day {
  if ([_day length] > 1) {
    /* be tolerant */
    unichar c0, c1;
    
    c0 = [_day characterAtIndex:0];
    if (c0 == 'm' || c0 == 'M') return iCalWeekDayMonday;
    if (c0 == 'w' || c0 == 'W') return iCalWeekDayWednesday;
    if (c0 == 'f' || c0 == 'F') return iCalWeekDayFriday;

    c1 = [_day characterAtIndex:1];
    if (c0 == 't' || c0 == 'T') {
      if (c1 == 'u' || c1 == 'U') return iCalWeekDayTuesday;
      if (c1 == 'h' || c1 == 'H') return iCalWeekDayThursday;
    }
    if (c0 == 's' || c0 == 'S') {
      if (c1 == 'a' || c1 == 'A') return iCalWeekDaySaturday;
      if (c1 == 'u' || c1 == 'U') return iCalWeekDaySunday;
    }
  }
  
  // TODO: do not raise but rather return an error value?
  [NSException raise:NSGenericException
	       format:@"Incorrect weekDay '%@' specified!", _day];
  return iCalWeekDayMonday; /* keep compiler happy */
}

- (NSString *)iCalRepresentationForWeekDay:(iCalWeekDay)_weekDay {
  switch (_weekDay) {
    case iCalWeekDayMonday:    return @"MO";
    case iCalWeekDayTuesday:   return @"TU";
    case iCalWeekDayWednesday: return @"WE";
    case iCalWeekDayThursday:  return @"TH";
    case iCalWeekDayFriday:    return @"FR";
    case iCalWeekDaySaturday:  return @"SA";
    case iCalWeekDaySunday:    return @"SU";
    default:                   return @"MO"; // TODO: return error?
  }
}

- (NSString *)freq {
  switch (self->frequency) {
    case iCalRecurrenceFrequenceWeekly:   return @"WEEKLY";
    case iCalRecurrenceFrequenceMonthly:  return @"MONTHLY";
    case iCalRecurrenceFrequenceDaily:    return @"DAILY";
    case iCalRecurrenceFrequenceYearly:   return @"YEARLY";
    case iCalRecurrenceFrequenceHourly:   return @"HOURLY";
    case iCalRecurrenceFrequenceMinutely: return @"MINUTELY";
    case iCalRecurrenceFrequenceSecondly: return @"SECONDLY";
    default:
      return @"UNDEFINED?";
  }
}

- (NSString *)wkst {
  return [self iCalRepresentationForWeekDay:self->byDay.weekStart];
}

/*
  TODO:
  Each BYDAY value can also be preceded by a positive (+n) or negative
  (-n) integer. If present, this indicates the nth occurrence of the
  specific day within the MONTHLY or YEARLY RRULE. For example, within
  a MONTHLY rule, +1MO (or simply 1MO) represents the first Monday
  within the month, whereas -1MO represents the last Monday of the
  month. If an integer modifier is not present, it means all days of
  this type within the specified frequency. For example, within a
  MONTHLY rule, MO represents all Mondays within the month.
*/
- (NSString *)byDayList {
  NSMutableString *s;
  unsigned        dow, mask, day;
  BOOL            needsComma;
  
  s          = [NSMutableString stringWithCapacity:20];
  needsComma = NO;
  mask       = self->byDay.mask;
  day        = iCalWeekDayMonday;
  
  for (dow = 0 /* Sun */; dow < 7; dow++) {
    if (mask & day) {
      if (needsComma)
        [s appendString:@","];
      
      if (self->byDay.useOccurence)
	// Note: we only support one occurrence for all currently
	[s appendFormat:@"%i", self->byDayOccurence1];
      
      [s appendString:[self iCalRepresentationForWeekDay:day]];
      needsComma = YES;
    }
    day = (day << 1);
  }
  return s;
}

/* Rule */

- (void)setRrule:(NSString *)_rrule {
  ASSIGNCOPY(self->rrule, _rrule);
  [self _parseRuleString:self->rrule];
}

/* parsing rrule */

- (void)_parseRuleString:(NSString *)_rrule {
  // TODO: to be exact we would need a timezone to properly process the 'until'
  //       date
  NSArray  *props;
  unsigned i, count;
  NSString *pFrequency = nil;
  NSString *pUntil     = nil;
  NSString *pCount     = nil;
  NSString *pByday     = nil;
  NSString *pBymday    = nil;
  NSString *pBymonth   = nil;
  NSString *pBysetpos  = nil;
  NSString *pInterval  = nil;
  
  props = [_rrule componentsSeparatedByString:@";"];
  for (i = 0, count = [props count]; i < count; i++) {
    NSString *prop, *key, *value;
    NSRange  r;
    NSString **vHolder = NULL;
    
    prop = [props objectAtIndex:i];
    r    = [prop rangeOfString:@"="];
    if (r.length > 0) {
      key   = [prop substringToIndex:r.location];
      value = [prop substringFromIndex:NSMaxRange(r)];
    }
    else {
      key   = prop;
      value = nil;
    }
    
    key = [[key stringByTrimmingSpaces] lowercaseString];
    if (![key isNotEmpty]) {
      [self errorWithFormat:@"empty component in rrule: %@", _rrule];
      continue;
    }
    
    vHolder = NULL;
    switch ([key characterAtIndex:0]) {
    case 'b':
      if ([key isEqualToString:@"byday"])      { vHolder = &pByday;    break; }
      if ([key isEqualToString:@"bymonthday"]) { vHolder = &pBymday;   break; }
      if ([key isEqualToString:@"bysetpos"])   { vHolder = &pBysetpos; break; }
      if ([key isEqualToString:@"bymonth"])    { vHolder = &pBymonth;  break; }
      break;
    case 'c':
      if ([key isEqualToString:@"count"]) { vHolder = &pCount; break; }
      break;
    case 'f':
      if ([key isEqualToString:@"freq"]) { vHolder = &pFrequency; break; }
      break;
    case 'i':
      if ([key isEqualToString:@"interval"]) { vHolder = &pInterval; break; }
      break;
    case 'u':
      if ([key isEqualToString:@"until"]) { vHolder = &pUntil; break; }
      break;
    default:
      break;
    }
    
    if (vHolder != NULL) {
      if ([*vHolder isNotEmpty])
        [self errorWithFormat:@"more than one '%@' in: %@", key, _rrule];
      else
        *vHolder = [value copy];
    }
    else {
      // TODO: we should just parse known keys and put remainders into a
      //       separate dictionary
      [self logWithFormat:@"TODO: add explicit support for key: %@", key];
      [self takeValue:value forKey:key];
    }
  }
  
  /* parse and fill individual values */
  // TODO: this method should be a class method and create a new rrule object
  
  if ([pFrequency isNotEmpty])
    [self setFreq:pFrequency];
  else
    [self errorWithFormat:@"rrule contains no frequency: '%@'", _rrule];
  [pFrequency release]; pFrequency = nil;
  
  if (pInterval != nil)
    self->interval = [pInterval intValue];
  [pInterval release]; pInterval = nil;
  
  // TODO: we should parse byday in here
  if (pByday != nil) [self setByday:pByday];
  [pByday release]; pByday = nil;
  
  // TODO: we should process bymonth here
  if (pBymonth != nil) {
    /* eg this is used in Sunbird 0.3 timezone descriptions */
    static BOOL didWarn = NO;
    if (!didWarn) {
      [self warnWithFormat:
	      @"not yet processing 'bymonth' fields of rrules: %@", _rrule];
      didWarn = YES;
    }
    [pBymonth release]; pBymonth = nil;
  }
  
  if (pBymday != nil) {
    NSArray *t;
    
    t = [pBymday componentsSeparatedByString:@","];
    ASSIGNCOPY(self->byMonthDay, t);
  }
  [pBymday release]; pBymday = nil;
  
  if (pBysetpos != nil)
    // TODO: implement
    [self errorWithFormat:@"rrule contains bysetpos, unsupported: %@", _rrule];
  [pBysetpos release]; pBysetpos = nil;
  
  if (pUntil != nil) {
    NSCalendarDate *pUntilDate;
    
    if (pCount != nil) {
      [self errorWithFormat:@"rrule contains 'count' AND 'until': %@", _rrule];
      [pCount release];
      pCount = nil;
    }
    
    /*
      The spec says:
        "If specified as a date-time value, then it MUST be specified in an
         UTC time format."
      TODO: we still need some object representing a 'timeless' date.
    */
    if (![pUntil hasSuffix:@"Z"] && [pUntil length] > 8) {
      [self warnWithFormat:@"'until' date has no explicit UTC marker: '%@'",
              _rrule];
    }
    
    pUntilDate = [NSCalendarDate calendarDateWithICalRepresentation:pUntil];
    if (pUntilDate != nil)
      [self setUntilDate:pUntilDate];
    else {
      [self errorWithFormat:@"could not parse 'until' in rrule: %@", 
              _rrule];
    }
  }
  [pUntil release]; pUntil = nil;
  
  if (pCount != nil) 
    [self setRepeatCount:[pCount intValue]];
  [pCount release]; pCount = nil;
}


/* properties */

- (void)setFreq:(NSString *)_freq {
  // TODO: shouldn't we preserve what the user gives us?
  // => only used by -_parseRuleString: parser?
  _freq = [_freq uppercaseString];
  if ([_freq isEqualToString:@"WEEKLY"])
    self->frequency = iCalRecurrenceFrequenceWeekly;
  else if ([_freq isEqualToString:@"MONTHLY"])
    self->frequency = iCalRecurrenceFrequenceMonthly;
  else if ([_freq isEqualToString:@"DAILY"])
    self->frequency = iCalRecurrenceFrequenceDaily;
  else if ([_freq isEqualToString:@"YEARLY"])
    self->frequency = iCalRecurrenceFrequenceYearly;
  else if ([_freq isEqualToString:@"HOURLY"])
    self->frequency = iCalRecurrenceFrequenceHourly;
  else if ([_freq isEqualToString:@"MINUTELY"])
    self->frequency = iCalRecurrenceFrequenceMinutely;
  else if ([_freq isEqualToString:@"SECONDLY"])
    self->frequency = iCalRecurrenceFrequenceSecondly;
  else {
    [NSException raise:NSGenericException
                 format:@"Incorrect frequency '%@' specified!", _freq];
  }
}

- (void)setInterval:(NSString *)_interval {
  self->interval = [_interval intValue];
}
- (void)setCount:(NSString *)_count {
  self->repeatCount = [_count unsignedIntValue];
}
- (void)setUntil:(NSString *)_until {
  NSCalendarDate *date;

  date = [NSCalendarDate calendarDateWithICalRepresentation:_until];
  ASSIGN(self->untilDate, date);
}

- (void)setWkst:(NSString *)_weekStart {
  self->byDay.weekStart = [self weekDayFromICalRepresentation:_weekStart];
}

- (void)setByday:(NSString *)_byDayList {
  // TODO: each day can have an associated occurence, eg:
  //        +1MO,+2TU,-9WE
  // TODO: this should be moved to the parser
  NSArray  *days;
  unsigned i, count;
  
  /* reset mask */
  self->byDay.mask = 0;
  self->byDay.useOccurence = 0;
  self->byDayOccurence1 = 0;
  
  days  = [_byDayList componentsSeparatedByString:@","];
  for (i = 0, count = [days count]; i < count; i++) {
    NSString    *iCalDay;
    iCalWeekDay day;
    unsigned    len;
    unichar     c0;
    int         occurence;
    
    iCalDay = [days objectAtIndex:i]; // eg: MO or TU
    if ((len = [iCalDay length]) == 0) {
      [self errorWithFormat:@"found an empty day in byday list: '%@'", 
	      _byDayList];
      continue;
    }
    
    c0 = [iCalDay characterAtIndex:0];
    if (((c0 == '+' || c0 == '-') && len > 2) || (isdigit(c0) && len > 1)) {
      int offset;
      
      occurence = [iCalDay intValue];
      
      offset = 1; /* skip occurence */
      while (offset < len && isdigit([iCalDay characterAtIndex:offset]))
	offset++;
      
      iCalDay = [iCalDay substringFromIndex:offset];
      
      if (self->byDay.useOccurence && (occurence != self->byDayOccurence1)) {
	[self errorWithFormat:
		@"we only supported one occurence (occ=%i,day=%@): '%@'", 
	        occurence, iCalDay, _byDayList];
	continue;
      }
      
      self->byDay.useOccurence = 1;
      self->byDayOccurence1 = occurence;
    }
    else if (self->byDay.useOccurence) {
      [self errorWithFormat:
	      @"a byday occurence was specified on one day, but not on others"
	      @" (unsupported): '%@'", _byDayList];
    }
    
    day = [self weekDayFromICalRepresentation:iCalDay];
    self->byDay.mask |= day;
  }
}

/* key/value coding */

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key {
  [self warnWithFormat:@"Cannot handle unbound key: '%@'", _key];
}


/* description */

- (NSString *)iCalRepresentation {
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:80];

  [s appendString:@"FREQ="];
  [s appendString:[self freq]];

  if ([self repeatInterval] != 1)
    [s appendFormat:@";INTERVAL=%d", [self repeatInterval]];
  
  if (![self isInfinite]) {
    if ([self repeatCount] > 0) {
      [s appendFormat:@";COUNT=%d", [self repeatCount]];
    }
    else {
      [s appendString:@";UNTIL="];
      [s appendString:[[self untilDate] icalString]];
    }
  }
  if (self->byDay.weekStart != iCalWeekDayMonday) {
    [s appendString:@";WKST="];
    [s appendString:[self iCalRepresentationForWeekDay:self->byDay.weekStart]];
  }
  if (self->byDay.mask != 0) {
    [s appendString:@";BYDAY="];
    [s appendString:[self byDayList]];
  }
  return s;
}

- (NSString *)description {
  return [self iCalRepresentation];
}

@end /* iCalRecurrenceRule */
