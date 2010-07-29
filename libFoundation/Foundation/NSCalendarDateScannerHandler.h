/* 
   NSCalendarDateScannerHandler.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSCalendarDateScannerHandler_h__
#define __NSCalendarDateScannerHandler_h__

#include <Foundation/NSCalendarDate.h>
#include <extensions/DefaultScannerHandler.h>

/*
 * This class is used internally by the NSCalendarDate class to create a string
 * representation from a calendar date object. The class that performs the
 * reverse operation, i.e. parses a string description and initializes a
 * calendar date object is the NSCalendarDateFormatScanner class.
 */

@interface NSCalendarDateScannerHandler : DefaultScannerHandler
{
    NSCalendarDate* date;
    NSTimeZoneDetail* detail;

    unsigned year;
    unsigned month;
    unsigned day;
    unsigned hour;
    unsigned minute;
    unsigned second;
    int timeZoneOffset;
    unsigned weekDay;
}

- initForCalendarDate:(NSCalendarDate*)date
  timeZoneDetail:(NSTimeZoneDetail*)detail;

- (NSString*)shortDayOfWeek:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)fullDayOfWeek:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)shortMonthOfYear:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)fullMonthOfYear:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)localeFormatForDateAndTime:(va_list*)pInt
  scanner:(FormatScanner*)scanner;
- (NSString*)decimalDayOfMonth:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)decimal24HourOfDay:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)decimal12HourOfDay:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)decimalDayOfYear:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)decimalMonthOfYear:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)decimalMinuteOfHour:(va_list*)pInt
  scanner:(FormatScanner*)scanner;
- (NSString*)AM_PM:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)decimalSecondOfMinute:(va_list*)pInt
  scanner:(FormatScanner*)scanner;
- (NSString*)decimalDayOfWeek:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)localeDate:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)localeTime:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)yearWithoutCentury:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)yearWithCentury:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)timeZoneName:(va_list*)pInt scanner:(FormatScanner*)scanner;
- (NSString*)timeZoneOffsetFromGMT:(va_list*)pInt
  scanner:(FormatScanner*)scanner;

@end

#endif /* __NSCalendarDateScannerHandler_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
