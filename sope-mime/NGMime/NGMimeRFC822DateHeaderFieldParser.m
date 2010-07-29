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

#include "NGMimeHeaderFieldParser.h"
#include "NGMimeHeaderFields.h"
#include "NGMimeUtilities.h"
#include "common.h"
#include <string.h>

@implementation NGMimeRFC822DateHeaderFieldParser

static Class CalDateClass = Nil;
static NSTimeZone *gmt   = nil;
static NSTimeZone *gmt01 = nil;
static NSTimeZone *gmt02 = nil;
static NSTimeZone *gmt03 = nil;
static NSTimeZone *gmt04 = nil;
static NSTimeZone *gmt05 = nil;
static NSTimeZone *gmt06 = nil;
static NSTimeZone *gmt07 = nil;
static NSTimeZone *gmt08 = nil;
static NSTimeZone *gmt09 = nil;
static NSTimeZone *gmt10 = nil;
static NSTimeZone *gmt11 = nil;
static NSTimeZone *gmt12 = nil;
static NSTimeZone *gmt0530 = nil;
static NSTimeZone *gmtM01 = nil;
static NSTimeZone *gmtM02 = nil;
static NSTimeZone *gmtM03 = nil;
static NSTimeZone *gmtM04 = nil;
static NSTimeZone *gmtM05 = nil;
static NSTimeZone *gmtM06 = nil;
static NSTimeZone *gmtM07 = nil;
static NSTimeZone *gmtM08 = nil;
static NSTimeZone *gmtM09 = nil;
static NSTimeZone *gmtM10 = nil;
static NSTimeZone *gmtM11 = nil;
static NSTimeZone *gmtM12 = nil;
static NSTimeZone *gmtM13 = nil;
static NSTimeZone *gmtM14 = nil;
static NSTimeZone *met    = nil;

+ (int)version {
  return 2;
}
+ (void)initialize {
  static BOOL didInit = NO;
  Class TzClass;
  if (didInit) return;
  didInit = YES;
  
  CalDateClass = [NSCalendarDate class];
  
  /* timezones which were actually used in a maillist mailbox */
  TzClass = [NSTimeZone class];
  gmt    = [[TzClass timeZoneWithName:@"GMT"] retain];
  met    = [[TzClass timeZoneWithName:@"MET"] retain];
  gmt01  = [[TzClass timeZoneForSecondsFromGMT:  1 * (60 * 60)] retain];
  gmt02  = [[TzClass timeZoneForSecondsFromGMT:  2 * (60 * 60)] retain];
  gmt03  = [[TzClass timeZoneForSecondsFromGMT:  3 * (60 * 60)] retain];
  gmt04  = [[TzClass timeZoneForSecondsFromGMT:  4 * (60 * 60)] retain];
  gmt05  = [[TzClass timeZoneForSecondsFromGMT:  5 * (60 * 60)] retain];
  gmt06  = [[TzClass timeZoneForSecondsFromGMT:  6 * (60 * 60)] retain];
  gmt07  = [[TzClass timeZoneForSecondsFromGMT:  7 * (60 * 60)] retain];
  gmt08  = [[TzClass timeZoneForSecondsFromGMT:  8 * (60 * 60)] retain];
  gmt09  = [[TzClass timeZoneForSecondsFromGMT:  9 * (60 * 60)] retain];
  gmt10  = [[TzClass timeZoneForSecondsFromGMT: 10 * (60 * 60)] retain];
  gmt11  = [[TzClass timeZoneForSecondsFromGMT: 11 * (60 * 60)] retain];
  gmt12  = [[TzClass timeZoneForSecondsFromGMT: 12 * (60 * 60)] retain];
  gmtM01 = [[TzClass timeZoneForSecondsFromGMT: -1 * (60 * 60)] retain];
  gmtM02 = [[TzClass timeZoneForSecondsFromGMT: -2 * (60 * 60)] retain];
  gmtM03 = [[TzClass timeZoneForSecondsFromGMT: -3 * (60 * 60)] retain];
  gmtM04 = [[TzClass timeZoneForSecondsFromGMT: -4 * (60 * 60)] retain];
  gmtM05 = [[TzClass timeZoneForSecondsFromGMT: -5 * (60 * 60)] retain];
  gmtM06 = [[TzClass timeZoneForSecondsFromGMT: -6 * (60 * 60)] retain];
  gmtM07 = [[TzClass timeZoneForSecondsFromGMT: -7 * (60 * 60)] retain];
  gmtM08 = [[TzClass timeZoneForSecondsFromGMT: -8 * (60 * 60)] retain];
  gmtM09 = [[TzClass timeZoneForSecondsFromGMT: -9 * (60 * 60)] retain];
  gmtM10 = [[TzClass timeZoneForSecondsFromGMT:-10 * (60 * 60)] retain];
  gmtM11 = [[TzClass timeZoneForSecondsFromGMT:-11 * (60 * 60)] retain];
  gmtM12 = [[TzClass timeZoneForSecondsFromGMT:-12 * (60 * 60)] retain];
  gmtM13 = [[TzClass timeZoneForSecondsFromGMT:-13 * (60 * 60)] retain];
  gmtM14 = [[TzClass timeZoneForSecondsFromGMT:-14 * (60 * 60)] retain];
  
  gmt0530 = [[TzClass timeZoneForSecondsFromGMT:5 * (60*60) + (30*60)] retain];
}

/* 
   All the date formats are more or less the same. If they start with a char
   those can be skipped to the first digit (since it is the weekday name that
   is unnecessary for date construction).
   
   TODO: use an own parser for that.
*/

static int parseMonthOfYear(unsigned char *s, unsigned int len) {
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

static NSTimeZone *parseTimeZone(unsigned char *s, unsigned int len) {
  /*
    WARNING: failed to parse RFC822 timezone: '+0530' \
             (value='Tue, 13 Jul 2004 21:39:28 +0530')
    TODO: this is because libFoundation doesn't accept 'GMT+0530' as input.
  */
  char       *p = (char *)s;
  NSTimeZone *tz;
  NSString   *ts;
  
  if (len == 0) 
    return nil;
  
  if (*s == '+' || *s == '-') {
    if (len == 3) {
      if (p[1] == '0' && p[2] == '0') // '+00' or '-00'
	return gmt;
      if (*s == '+') {
	if (p[1] == '0' && p[2] == '1') // '+01'
	  return gmt01;
	if (p[1] == '0' && p[2] == '2') // '+02'
	  return gmt02;
      }
    }
    else if (len == 5) {
      if (p[3] == '0' && p[4] == '0' && p[1] == '0') { // '?0x00'
	if (p[2] == '0') // '+0000'
	  return gmt;
	
	if (*s == '+') {
	  if (p[2] == '1') return gmt01; // '+0100'
	  if (p[2] == '2') return gmt02; // '+0200'
	  if (p[2] == '3') return gmt03; // '+0300'
	  if (p[2] == '4') return gmt04; // '+0400'
	  if (p[2] == '5') return gmt05; // '+0500'
	  if (p[2] == '6') return gmt06; // '+0600'
	  if (p[2] == '7') return gmt07; // '+0700'
	  if (p[2] == '8') return gmt08; // '+0800'
	  if (p[2] == '9') return gmt09; // '+0900'
	}
	else if (*s == '-') {
          if (p[2] == '1') return gmtM01; // '-0100'
          if (p[2] == '2') return gmtM02; // '-0200'
          if (p[2] == '3') return gmtM03; // '-0300'
	  if (p[2] == '4') return gmtM04; // '-0400'
	  if (p[2] == '5') return gmtM05; // '-0500'
	  if (p[2] == '6') return gmtM06; // '-0600'
	  if (p[2] == '7') return gmtM07; // '-0700'
	  if (p[2] == '8') return gmtM08; // '-0800'
	  if (p[2] == '9') return gmtM09; // '-0900'
	}
      }
      else if (p[3] == '0' && p[4] == '0' && p[1] == '1') { // "?1x00"
        if (*s == '+') {
          if (p[2] == '0') return gmt10; // '+1000'
          if (p[2] == '1') return gmt11; // '+1100'
          if (p[2] == '2') return gmt12; // '+1200'
        }
        else if (*s == '-') {
          if (p[2] == '0') return gmtM10; // '-1000'
          if (p[2] == '1') return gmtM11; // '-1100'
          if (p[2] == '2') return gmtM12; // '-1200'
          if (p[2] == '3') return gmtM13; // '-1300'
          if (p[2] == '4') return gmtM14; // '-1400'
        }
      }
      
      /* special case for GMT+0530 */
      if (strncmp((char *)s, "+0530", 5) == 0)
	return gmt0530;
    }
    else if (len == 7) {
      /*
        "MultiMail" submits timezones like this: 
          "Tue, 9 Mar 2004 9:43:00 -05-500",
        don't know what the "-500" trailer is supposed to mean? Apparently 
        Thunderbird just uses the "-05", so do we.
      */
      
      if (isdigit(p[1]) && isdigit(p[2]) && (p[3] == '-'||p[3] == '+')) {
        unsigned char tmp[8];
        
        strncpy((char *)tmp, p, 3);
        tmp[3] = '0';
        tmp[4] = '0';
        tmp[5] = '\0';
        return parseTimeZone(tmp, 5);
      }
    }
  }
  else if (*s == '0') {
    if (len == 2) { // '00'
      if (p[1] == '0') return gmt;
      if (p[1] == '1') return gmt01;
      if (p[1] == '2') return gmt02;
    }
    else if (len == 4) {
      if (p[2] == '0' && p[3] == '0') { // '0x00'
	if (p[1] == '0') return gmt;
	if (p[1] == '1') return gmt01;
	if (p[1] == '2') return gmt02;
      }
    }
  }
  else if (len == 3) {
    if (strcasecmp((char *)s, "GMT") == 0) return gmt;
    if (strcasecmp((char *)s, "UTC") == 0) return gmt;
    if (strcasecmp((char *)s, "MET") == 0) return met;
    if (strcasecmp((char *)s, "CET") == 0) return met;
  }
  
  if (isalpha(*s)) {
    ts = [[NSString alloc] initWithCString:(char *)s length:len];
  }
  else {
    char buf[len + 5];
    
    buf[0] = 'G'; buf[1] = 'M'; buf[2] = 'T';
    if (*s == '+' || *s == '-') {
      strcpy(&(buf[3]), (char *)s);
    }
    else {
      buf[3] = '+';
      strcpy(&(buf[4]), (char *)s);
    }
    ts = [[NSString alloc] initWithCString:buf];
  }
#if 1
  NSLog(@"%s: RFC822 TZ Parser: expensive: '%@'", __PRETTY_FUNCTION__, ts);
#endif
  tz = [NSTimeZone timeZoneWithAbbreviation:ts];
  [ts release];
  return tz;
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  // TODO: use UNICODE
  NSCalendarDate *date       = nil;
  unsigned char  buf[256];
  unsigned char  *bytes = buf, *pe;
  unsigned       length = 0;
  NSTimeZone     *tz = nil;
  char  dayOfMonth, monthOfYear, hour, minute, second;
  short year;
  BOOL  flag;
  
  if ((length = [_data cStringLength]) > 254) {
    [self logWithFormat:
	    @"header field value to large for date parsing: '%@'(%i)",
	    _data, length];
    length = 254;
  }
  
  [_data getCString:(char *)buf maxLength:length];
  buf[length] = '\0';
  
  /* remove leading chars (skip to first digit, the day of the month) */
  while (length > 0 && (!isdigit(*bytes))) {
    bytes++;
    length--;
  }
  
  if (length == 0) {
    NSLog(@"WARNING(%s): empty value for header field %@ ..",
          __PRETTY_FUNCTION__, _field);
    return [CalDateClass date];
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
  if ((tz = parseTimeZone(bytes, (pe - bytes))) == nil) {
    [self logWithFormat:
            @"WARNING: failed to parse RFC822 timezone: '%s' (value='%@')",
	    bytes, _data];
    tz = gmt;
  }
  
  /* construct and return */
 finished:  
  date = [CalDateClass dateWithYear:year month:monthOfYear day:dayOfMonth
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
