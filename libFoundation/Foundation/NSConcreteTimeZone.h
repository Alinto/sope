/* 
   NSConcreteTimeZone.h

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

#ifndef __NSConcreteTimeZone_h__
#define __NSConcreteTimeZone_h__

#include <Foundation/NSDate.h>

@class NSString;
@class NSArray;
@class NSMutableArray;

@interface NSConcreteTimeZone : NSTimeZone
{
    NSString* name;
    NSArray*  timeZoneDetails;
}
+ timeZoneWithOffset:(int)seconds;
- initWithName:(NSString*)name;
- (NSString*)timeZoneName;
- (NSArray*)timeZoneDetailArray;
@end

@interface NSConcreteTimeZoneFile : NSConcreteTimeZone
{
    NSString*       filename;
    NSMutableArray* transitions;
}
- initFromFile:(NSString*)filename withName:(NSString*)name;

- (NSArray*)timeZoneDetailArray;
- (NSString*)filename;

/* Private methods */
- (void)_initFromFile;
- detailWithName:(NSString*)name;
- (NSArray*)transitions;
@end


/* Below are the classes used to represent a time zone description file.
   The transitions and rules from the time zone file are stored in the
   `transitions' array in a NSConcreteTimeZoneFile instance. Each transition
   is represented by a NSTimeZoneTransitionDate instance. Each rule is
   represented by a NSTimeZoneTransitionRule instance.

   When -timeZoneDetailForDate: message is sent to a NSConcreteTimeZoneFile
   object, it searches the argument date in the `transitions' array for a
   matching date or for the dates it is in between. The comparison is made
   by sending the -compare: message. A rule object responds to this message
   by comparing the argument date with is start and end dates. After a
   transition object was identified it receives the message -detailForDate:
   to obtain the time zone detail object that will be finally returned.
*/

@class NSTimeZoneRule;

@interface NSTimeZoneTransitionDate : NSObject
{
    NSCalendarDate *date;
    id             detail;
}
+ (NSTimeZoneTransitionDate *)transitionDateFromPropertyList:(id)plist
  timezone:(id)tz;
- (id)initWithDate:(NSDate *)date detail:detail;
- (id)detailForDate:(NSCalendarDate *)date;
- (NSCalendarDate *)date;
- (NSComparisonResult)compare:(id)tranDateOrTranRule;

- detailAfterLastDate;
@end

@interface NSTimeZoneTransitionRule : NSObject
{
    NSCalendarDate *startDate;
    NSCalendarDate *endDate;
    NSTimeZoneRule *startRule;
    NSTimeZoneRule *endRule;
}
+ (NSTimeZoneTransitionRule*)transitionRuleFromPropertyList:(id)plist
  timezone:(id)tz;
- (id)detailForDate:(NSCalendarDate*)date;
- (NSComparisonResult)compare:tranDateOrTranRule;
- (NSCalendarDate*)startDate;
- (NSCalendarDate*)endDate;

- detailAfterLastDate;
@end

@interface NSTimeZoneRule : NSObject
{
    int monthOfYear;
    int weekOfMonth;
    int dayOfWeek;
    int hours;
    int minutes;
    int seconds;
    id  detail;
}
+ (NSTimeZoneRule*)ruleFromPropertyList:(id)plist
  timezone:(id)tz;
- (NSCalendarDate*)dateInYear:(int)year;
- detail;
@end

#endif /* __NSConcreteTimeZone_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
