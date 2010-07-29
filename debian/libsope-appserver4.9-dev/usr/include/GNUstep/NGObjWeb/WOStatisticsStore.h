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

#ifndef __NGObjWeb_WOStatisticsStore_H__
#define __NGObjWeb_WOStatisticsStore_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSDate.h>

@class NSString, NSDictionary, NSMutableDictionary;
@class WOResponse, WOContext;

@interface WOStatisticsStore : NSObject < NSLocking >
{
  id<NSLocking,NSObject> lock;
  NSDate   *startTime;
  
  NSMutableDictionary *pageStatistics;
  unsigned       totalResponseCount;
  unsigned       pageResponseCount;
  unsigned       totalResponseSize;
  unsigned       zippedResponsesCount;
  unsigned       totalZippedSize;
  int            smallestResponseSize;
  unsigned       largestResponseSize;
  NSTimeInterval minimumDuration;
  NSTimeInterval maximumDuration;
  NSTimeInterval totalDuration;
}

/* query */

- (NSDictionary *)statistics;

/* recording */

- (void)recordStatisticsForResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

- (NSString *)descriptionForResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

/* formatting */

- (NSString *)formatDescription:(NSString *)_description
  forResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

/* NSLocking */

- (void)lock;
- (void)unlock;

@end

#endif /* __NGObjWeb_WOStatisticsStore_H__ */
