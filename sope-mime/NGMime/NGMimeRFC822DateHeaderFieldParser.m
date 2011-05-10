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

#include <string.h>

#include "NGMimeHeaderFieldParser.h"
#include "NGMimeHeaderFields.h"
#include "NGMimeUtilities.h"
#include "common.h"

@implementation NGMimeRFC822DateHeaderFieldParser

static NSTimeZone *gmt = nil;
static NSTimeZone *met = nil;

+ (int)version {
  return 2;
}

+ (void)initialize {
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  gmt = [[NSTimeZone timeZoneWithName:@"GMT"] retain];
  met = [[NSTimeZone timeZoneWithName:@"MET"] retain];
}

/* 
   All the date formats are more or less the same. If they start with a char
   those can be skipped to the first digit (since it is the weekday name that
   is unnecessary for date construction).
   
   TODO: use an own parser for that.
*/

static int parseMonthOfYear(char *s, unsigned int len) {
  /*
    This one is *extremely* forgiving, it only checks what is
    necessary for the set below. This should work for both, English
    and German.
    
    English: Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec
             J    F    M    A    M    J    J    A    S    O    N    D
  */
  if (len < 3) {
    NSLog(@"RFC822 Parser: cannot process month name: '%s'", s);
    return 0;
  }
  switch (toupper(*s)) {
  case 'A': // April, August
    if (toupper(s[1]) == 'P') return 4; // Apr
    return 8; // Aug
  case 'D': return 12; // Dec
  case 'F': return  2; // Feb
  case 'J': // Jan, Jun, Jul
    if (toupper(s[1]) == 'A') return 1; // Jan
    if (toupper(s[2]) == 'N') return 6; // Jun
    return 7; // Jul
  case 'M': // Mar, May
    if (toupper(s[2]) == 'Y' || toupper(s[2]) == 'I') // May or Mai (German ;-)
      return 5;
    return 3; // Mar
  case 'N': return 11; // Nov
  case 'O': return 10; // Oct
  case 'S': return  9; // Sep
  default:
    NSLog(@"RFC822 Parser: cannot process month name: '%s'", s);
    return 0;
  }
}

static int offsetFromTZAbbreviation(const char **p) {
  NSString *abbreviation;
  NSTimeZone *offsetTZ;
  unsigned int length;

  length = 0;
  while (isalpha(*(*p+length)))
    length++;
  abbreviation = [[NSString alloc] initWithBytes: *p
				   length: length - 1
				   encoding: NSISOLatin1StringEncoding];
  offsetTZ = [NSTimeZone timeZoneWithAbbreviation: abbreviation];
  [abbreviation release];
  *p += length;

  return [offsetTZ secondsFromGMT];
}

static inline char *digitsString(const char *string) {
  const char *p;
  unsigned int len;

  p = string;
  while (!isdigit(*p))
    p++;
  len = 0;
  while (isdigit(*(p + len)))
    len++;

  return strndup(p, len);
}
 
static NSTimeZone *parseTimeZone(const char *s, unsigned int len) {
  /*
    WARNING: failed to parse RFC822 timezone: '+0530' \
             (value='Tue, 13 Jul 2004 21:39:28 +0530')
    TODO: this is because libFoundation doesn't accept 'GMT+0530' as input.
  */
  char *newString, *digits;
  const char *p;
  NSTimeZone *tz;
  NSInteger hours, minutes, seconds, remaining;
  int sign;

  sign = 1;
  hours = 0;
  minutes = 0;
  seconds = 0;

  newString = strndup(s, len);
  p = newString;

  if (isalpha(*p))
    seconds = offsetFromTZAbbreviation(&p);
  while (isspace(*p))
    p++;
  while (*p == '+' || *p == '-') {
    if (*p == '-')
      sign = -sign;
    p++;
  }
  digits = NULL;
  if (strlen(p)) {
    digits = digitsString(p);
    p = digits;
  }
  remaining = strlen(p);
  switch(remaining) {
  case 6: /* hhmmss */
    seconds += (10 * (*(p + remaining - 2) - 48)
		+ *(p + remaining - 1) - 48);
  case 4: /* hhmm */
    hours += 10 * (*p - 48);
    p++;
  case 3: /* hmm */
    hours += (*p - 48);
    p++;
    minutes += 10 * (*p - 48) + *(p + 1) - 48;
    break;
  case 2: /* hh */
    hours += 10 * (*p - 48) + *(p + 1) - 48;
    break;
  default:
    NSLog (@"parseTimeZone: cannot parse time notation '%s'", newString);
  }
  free(digits);

  seconds += sign * (3600 * hours + 60 * minutes);
  tz = [NSTimeZone timeZoneForSecondsFromGMT: seconds];
  free(newString);

  return tz;
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  // TODO: use UNICODE
  NSCalendarDate *date       = nil;
  char	*allocBytes, *bytes, *pe;
  unsigned       length = 0;
  NSTimeZone     *tz = nil;
  char  dayOfMonth, monthOfYear, hour, minute, second;
  short year;
  BOOL  flag;

  length = [_data lengthOfBytesUsingEncoding: NSUTF8StringEncoding];

  if (length == 0) {
    NSLog(@"WARNING(%s): empty value for header field %@ ..",
          __PRETTY_FUNCTION__, _field);
    return [NSCalendarDate date];
  }

  allocBytes = strdup ([_data cStringUsingEncoding: NSUTF8StringEncoding]);
  bytes = allocBytes;

  /* remove leading chars (skip to first digit, the day of the month) */
  while (length > 0 && (!isdigit(*bytes))) {
    bytes++;
    length--;
  }
  
  // TODO: should be a category on NSCalendarDate
  // TODO: optimize much further!
  //   first part: '16 Jun 2002'
  //   snd   part: '12:28[:11]'
  //   trd   part: 'GMT' '+0000' '(MET)' '(+0200)'

  /* defaults for early aborts */
  tz     = gmt;
  second = 0;
  minute = 0;
  
  /* parse day of month */
  
  for (pe = bytes; isdigit(*pe); pe++)
    ;
  if (*pe == 0) goto failed;
  *pe = '\0';
  dayOfMonth = atoi((char *)bytes);
  bytes = pe + 1;
  
  /* parse month-abbrev (should be English, could be other langs) */
  
  while (!isalpha(*bytes)) { /* go to first char */
    if (*bytes == '\0') goto failed;
    bytes++;
  }
  for (pe = bytes; isalpha(*pe); pe++) /* find end of string */
    ;
  if (*pe == 0) goto failed;
  *pe = '\0';
  if ((monthOfYear = parseMonthOfYear(bytes, (pe - bytes))) == 0) {
    [self logWithFormat:@"WARNING(%s): cannot parse month in date: %@",
            __PRETTY_FUNCTION__, _data];
  }
  bytes = pe + 1;
  
  /* parse year */
  
  while (!isdigit(*bytes)) { /* go to first digit */
    if (*bytes == '\0') goto failed;
    bytes++;
  }
  for (pe = bytes; isdigit(*pe); pe++) /* find end of number */
    ;
  if (*pe == 0) goto failed;
  *pe = '\0';
  year = atoi((char *)bytes);
  bytes = pe + 1;
  if (year >= 70 && year < 135) // Y2K
    year += 1900;
  else if (year >= 0 && year < 70) // Y2K
    year += 2000;
  
#if LIB_FOUNDATION_LIBRARY
  if (year > 2030) {
    NSLog(@"ERROR(%s): got invalid year in date header %d: '%s'",
	  __PRETTY_FUNCTION__, year, buf);
    year = 2000; /* no choice is good ..., maybe return nil? */
  }
#endif
  
  /* parse hour */
  
  while (!isdigit(*bytes)) { /* go to first digit */
    if (*bytes == '\0') goto failed;
    bytes++;
  }
  for (pe = bytes; isdigit(*pe); pe++) /* find end of number */
    ;
  flag = (*pe == 0);
  *pe = '\0';
  hour = bytes != pe ? atoi((char *)bytes) : 0;
  if (flag) goto finished; // this is: '12\0'
  bytes = pe + 1;
  
  /* parse minute */
  
  while (!isdigit(*bytes)) { /* go to first digit */
    if (*bytes == '\0') goto finished; // this is: '12  \0'
    bytes++;
  }
  for (pe = bytes; isdigit(*pe); pe++) /* find end of number */
    ;
  flag = (*pe == 0);
  *pe = '\0';
  minute = bytes != pe ? atoi((char *)bytes) : 0;
  if (flag) goto finished; // this is: '12:23\0'
  bytes = pe + 1;
  
  /* parse second - if available '13:13:23' vs '12:23\0' or '12:12 (MET)' */
  
  while (isspace(*bytes)) /* skip spaces */
    bytes++;
  if (*bytes == 0) goto finished; // this is: '12:23   \0'
  if (isdigit(*bytes) || *bytes == ':') {
    /* parse second */
    while (!isdigit(*bytes)) { /* go to first digit, skip the ':' */
      if (*bytes == '\0') goto finished;
      bytes++;
    }
    
    for (pe = bytes; isdigit(*pe); pe++) /* find end of number */
      ;
    flag = (*pe == 0);
    *pe = '\0';
    second = bytes != pe ? atoi((char *)bytes) : 0;
    if (flag) goto finished; // this is: '12:23:12\0'
    bytes = pe + 1;
  }
  
  /* parse timezone: 'GMT' '+0000' '(MET)' '(+0200)' */
  // TODO: do we need to parse: "-0700 (PDT)" as "PDT"?
  
  while (isspace(*bytes) || *bytes == '(') /* skip spaces */
    bytes++;
  if (*bytes == 0) goto finished; // this is: '12:23:12 \0' or '12:12 ('
  
  for (pe = bytes; isalnum(*pe) || *pe == '-' || *pe == '+'; pe++)
    ;
  *pe = '\0';
  if (pe == bytes
      || (tz = parseTimeZone((const char *) bytes, (pe - bytes))) == nil) {
    [self logWithFormat:
            @"WARNING: failed to parse RFC822 timezone: '%s' (value='%@')",
	    bytes, _data];
    tz = gmt;
  }

  free (allocBytes);
  /* construct and return */
 finished:  
  date = [NSCalendarDate dateWithYear:year month:monthOfYear day:dayOfMonth
			 hour:hour minute:minute second:second
			 timeZone:tz];
  if (date == nil) goto failed;

#if 0  
  printf("parsed '%s' to date: %s\n", 
	 [_data cString], [[date description] cString]);
  //[self logWithFormat:@"parsed '%@' to date: %@", _data, date];
#endif
  return date;
  
 failed:
  // TODO: 'Sun, May 18 2003 14:20:55 -0700' - why does this fail?
  [self logWithFormat:@"WARNING: failed to parse RFC822 date field: '%@'",
	  _data];
  return nil;
}

@end /* NGMimeRFC822DateHeaderFieldParser */
