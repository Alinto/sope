/* 
   NSConcreteDate.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

#include "NSConcreteDate.h"

@implementation NSConcreteDate

- initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secsToBeAdded
{
    [super init];
    timeSinceRef = secsToBeAdded;
    return self;
}

- init
{
    [super init];
    timeSinceRef = [NSDate timeIntervalSinceReferenceDate];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    return [[[self class] allocWithZone:zone]
		initWithTimeIntervalSinceReferenceDate:timeSinceRef];
}

- (NSTimeInterval)timeIntervalSinceReferenceDate
{
    return timeSinceRef;
}

- (void)setTimeIntervalSinceReferenceDate:(NSTimeInterval)secsToBeAdded
{
    timeSinceRef = secsToBeAdded;
}

- (NSComparisonResult)compare:(NSDate*)other
{
    if ([other isKindOfClass:[NSDate class]]) {
	NSTimeInterval diff
	    = timeSinceRef - [other timeIntervalSinceReferenceDate];

	return (diff < 0 ?
		  NSOrderedAscending
		: (diff == 0 ? NSOrderedSame : NSOrderedDescending));
    }

    NSAssert(0, @"Cannot compare NSDate with %@", [other class]);
    return NSOrderedSame;
}

@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

