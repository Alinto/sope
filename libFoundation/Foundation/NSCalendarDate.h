/* 
   NSCalendarDate.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Private file used by NSCalendarDate related files.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#ifndef __NSCalendarDate_h__
#define __NSCalendarDate_h__

#include <Foundation/NSDate.h>

@interface NSCalendarDate (NSCalendarDateImplementation)

+ (NSString*)descriptionForCalendarDate:(NSCalendarDate*)date
  withFormat:(NSString*)format
  timeZoneDetail:(NSTimeZoneDetail*)detail
  locale:(NSDictionary*)locale;
+ (NSString*)shortDayOfWeek:(int)day;
+ (NSString*)fullDayOfWeek:(int)day;
+ (NSString*)shortMonthOfYear:(int)day;
+ (NSString*)fullMonthOfYear:(int)day;
+ (int)decimalDayOfYear:(int)year month:(int)month day:(int)day;

@end

#endif /* __NSCalendarDate_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
