/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

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

#include "NSString+Extensions.h"
#include "common.h"

@implementation NSString (ChangeLogSaxDriverExtensions)

typedef struct {
  unsigned minLength;
  unsigned offset;
  BOOL     hasTime;
  BOOL     hasTimeZone;
  NSString *format;
} dateFormatTest;

static dateFormatTest formats[] = {
  { 24, 4, YES,  NO, @"%b %d %H:%M:%S %Y"       },
  { 10, 0,  NO,  NO, @"%Y-%m-%d"                },
  { 12, 0,  NO,  NO, @"%b %d, %Y"               },
  { 13, 0,  NO,  NO, @"%b %d,  %Y"              },
  { 15, 5,  NO,  NO, @"%b %d  %Y"               },
  { 16, 0,  NO,  NO, @"%a %b %d  %Y"            },
  { 23, 3, YES,  NO, @"%b %d %H:%M:%S %Y"       },
  { 24, 4, YES,  NO, @"%d %b %Y %H:%M:%S"       },
  { 25, 4, YES,  NO, @"%b  %d %H:%M:%S %Y"      },
  { 25, 4, YES,  NO, @"%B %d %H:%M:%S %Y"       },
  { 28, 4, YES, YES, @"%b %d %H:%M:%S %Z %Y"    },
  { 30, 0, YES, YES, @"%a %b %d %H:%M:%S %Z %Y" },
  {  0, 0,  NO,  NO, nil                        } /* end marker */
};

typedef struct {
  unsigned minLength;
  unsigned start;
  unsigned stop;
  unsigned contAt;
  BOOL     hasTime;
  BOOL     hasTimeZone;
  NSString *format;
} complexDateFormatTest;

static complexDateFormatTest complexFormats[] = {
  { 28, 4, 20, 24, YES, NO, @"%b %d %H:%M:%S %Y" },
  { 29, 4, 20, 25, YES, NO, @"%b %d %H:%M:%S %Y" },
  { 29, 4, 20, 24, YES, NO, @"%b %d %H:%M:%S %Y" },
  {  0, 0,  0,  0,  NO, NO, nil                  } /* end marker */
};

- (BOOL)parseDate:(NSCalendarDate **)_date andAuthor:(NSString **)_author {
  static NSTimeZone   *gmt    = nil;
  static NSDictionary *locale = nil;
  NSString            *s, *format;
  NSCalendarDate      *date;
  NSRange             r;
  unsigned            i, endLoc, len;
  BOOL                hasTime, hasTimeZone;

  if(!gmt) {
    NSBundle *bundle;
    NSString *path;

    gmt = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];
    
    bundle = [NSBundle bundleForClass:[self class]];
    path   = [bundle pathForResource:@"default" ofType:@"locale"];
    if(path != nil) {
      locale = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
    }
  }

  date   = nil;
  endLoc = 0, i = 0;
  len    = [self length];

  /* perform basic tests */
  while((endLoc = formats[i].minLength) != 0 && endLoc < len) {
    r      = NSMakeRange(formats[i].offset,
                         endLoc - formats[i].offset);
    s      = [self substringWithRange:r];
    format = formats[i].format;
    date   = [NSCalendarDate dateWithString:s
                             calendarFormat:format
                             locale:locale];
    if(date) {
      hasTime     = formats[i].hasTime;
      hasTimeZone = formats[i].hasTimeZone;
      break;
    }
    i++;
  }

  if(!date) {
    /* perform complex tests */
    i = 0;
    while((endLoc = complexFormats[i].minLength) != 0 && endLoc < len)
    {
      
      r      = NSMakeRange(complexFormats[i].start,
                           complexFormats[i].stop - complexFormats[i].start);
      s      = [self substringWithRange:r];
      r      = NSMakeRange(complexFormats[i].contAt,
                           endLoc - complexFormats[i].contAt);
      s      = [NSString stringWithFormat:@"%@%@",
                                            s,
                                            [self substringWithRange:r]];
      format = complexFormats[i].format;
      date   = [NSCalendarDate dateWithString:s
                               calendarFormat:format
                               locale:locale];
      if(date) {
        hasTime     = complexFormats[i].hasTime;
        hasTimeZone = complexFormats[i].hasTimeZone;
        break;
      }
      i++;
    }
  }
  
  if(date) {
    if(!hasTimeZone && !hasTime)
      date = [NSCalendarDate dateWithYear:[date yearOfCommonEra]
                             month:[date monthOfYear]
                             day:[date dayOfMonth]
                             hour:12
                             minute:0
                             second:0
                             timeZone:gmt];
    else if(!hasTimeZone)
      [date setTimeZone:gmt];
    else if(!hasTime)
      date = [date hour:12 minute:0];
    
    *_author = [self substringFromIndex:endLoc];
  }
  else {
    *_author = nil;
  }
  *_date = date;
  return (date != nil) ? YES : NO;
}

- (void)getRealName:(NSString **)_realName andEmail:(NSString **)_email {
  NSRange  r;
  NSString *s;

  s = [self stringByTrimmingSpaces];
  r = [s rangeOfString:@"<"];
  if(r.length == 0) {
    *_realName = s;
    *_email    = nil;
    return;
  }
  if(r.location != 0) {
    NSString *rn;

    rn = [s substringToIndex:r.location];
    *_realName = [rn stringByTrimmingTailSpaces];
  }
  else {
    *_realName = @"";
  }
  s = [s substringFromIndex:NSMaxRange(r)];
  s = [s stringByTrimmingTailSpaces];
  s = [s substringToIndex:[s length] - 1];
  *_email = s;
}

@end
