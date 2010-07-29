/* 
   NSConcreteTimeZoneDetail.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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

#ifndef __NSConcreteTimeZoneDetail_h__
#define __NSConcreteTimeZoneDetail_h__

#include <Foundation/NSDate.h>

@class NSString;

@interface NSConcreteTimeZoneDetail : NSTimeZoneDetail
{
    NSString   *abbreviation;
    NSString   *name;	// not necessarily the same as abbreviation (see HST)
    int        offsetFromGMT;
    BOOL       isDST;
    NSTimeZone *parentZone; // non-retained !
}

// initializing
+ (id)detailFromPropertyList:(id)propList name:(NSString*)name
  parentZone:(NSTimeZone *)_zone;

- (id)initWithAbbreviation:(NSString*)anAbbreviation
  secondsFromGMT:(int)aDifference
  isDaylightSaving:(BOOL)aDst
  name:(NSString *)name
  parentZone:(NSTimeZone *)_zone;

// querying
- (BOOL)isDaylightSavingTimeZone;
- (NSString *)timeZoneAbbreviation;
- (NSString *)name;
- (int)timeZoneSecondsFromGMT;

// archiving
- (NSString *)description;

// Private
+ (int)_offsetFromString:(NSString*)string;

@end

#endif /* __NSConcreteTimeZoneDetail_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
