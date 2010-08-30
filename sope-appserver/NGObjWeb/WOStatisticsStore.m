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

#include <NGObjWeb/WOStatisticsStore.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@interface _WOPageStats : NSObject
{
@public
  NSString       *pageName;
  unsigned       totalResponseCount;
  unsigned       totalResponseSize;
  unsigned       zippedResponsesCount;
  unsigned       totalZippedSize;
  unsigned       largestResponseSize;
  unsigned       smallestResponseSize;
  NSTimeInterval minimumDuration;
  NSTimeInterval maximumDuration;
  NSTimeInterval totalDuration;
}
@end

@interface WORequest(UsedPrivates)
- (NSCalendarDate *)startDate;
- (id)startStatistics;
@end

@implementation WOStatisticsStore

static char *monthAbbr[13] = {
  "Dec",
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};
static NSTimeZone *gmt = nil;
static Class NSNumberClass    = Nil;
static Class NSStringClass    = Nil;
static BOOL  runMultithreaded = NO;

+ (int)version {
  return 1;
}

+ (void)initialize {
  NSNumberClass = [NSNumber class];
  NSStringClass = [NSString class];

  if (gmt == nil)
    gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
  
  runMultithreaded = [[NSUserDefaults standardUserDefaults]
		                      boolForKey:@"WORunMultithreaded"];
}

- (id)init {
  if ((self = [super init])) {
    self->startTime = [[NSDate date] copy];
    self->smallestResponseSize = -1;
    self->totalDuration = 0.0;
    
    if (runMultithreaded)
      self->lock = [[NSRecursiveLock alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self->pageStatistics release];
  [self->startTime      release];
  [self->lock           release];
  [super dealloc];
}

/* query */

static id mkuint(unsigned int i) {
  return [NSNumberClass numberWithUnsignedInt:i];
}
static id mkdbl(double d) {
#if 1 // TODO: why is that?
  char buf[64];
  sprintf(buf, "%.3f", d);
  return [NSStringClass stringWithCString:buf];
#else
  return [NSNumberClass numberWithDouble:d];
#endif
}

- (NSDictionary *)statisticsForPageNamed:(NSString *)_pageName {
  // TODO: fix inefficient use of NSString
  NSMutableDictionary *stats;
  _WOPageStats        *pageStats;

  if ((pageStats = [self->pageStatistics objectForKey:_pageName]) == nil)
    return nil;

  stats = [NSMutableDictionary dictionaryWithCapacity:16];

  [stats setObject:mkuint(pageStats->totalResponseSize)
         forKey:@"totalResponseSize"];
  [stats setObject:mkuint(pageStats->totalResponseCount)
         forKey:@"totalResponseCount"];
  [stats setObject:mkdbl(pageStats->totalDuration)
         forKey:@"totalDuration"];

  if (pageStats->smallestResponseSize >= 0) {
    [stats setObject:mkuint(pageStats->largestResponseSize)
           forKey:@"largestResponseSize"];
    [stats setObject:mkuint(pageStats->smallestResponseSize)
           forKey:@"smallestResponseSize"];
    [stats setObject:mkdbl(pageStats->minimumDuration)
           forKey:@"minimumDuration"];
    [stats setObject:mkdbl(pageStats->maximumDuration)
           forKey:@"maximumDuration"];
  }
  
  if (pageStats->totalResponseCount > 0) {
    [stats setObject:
             mkuint(pageStats->totalResponseSize/pageStats->totalResponseCount)
           forKey:@"averageResponseSize"];
    [stats setObject:
             mkdbl(pageStats->totalDuration / pageStats->totalResponseCount)
           forKey:@"averageDuration"];
  }
  
  [stats setObject:mkuint(pageStats->zippedResponsesCount)
         forKey:@"numberOfZippedResponses"];
  [stats setObject:mkuint(pageStats->totalZippedSize)
         forKey:@"totalZippedSize"];
  
  /* calc frequencies */
  {
    double d;
    
    d = ((double)self->totalResponseCount) / 100.0; // one percent
    d = ((double)pageStats->totalResponseCount) / d; // percents of total
    [stats setObject:[NSStringClass stringWithFormat:@"%.3f%%", d]
           forKey:@"responseFrequency"];
    
    d = ((double)self->totalDuration) / 100.0; // one percent
    d = ((double)pageStats->totalDuration) / d; // percents of total
    [stats setObject:[NSStringClass stringWithFormat:@"%.3f%%", d]
           forKey:@"relativeTimeConsumption"];
    
    d = ((double)self->pageResponseCount) / 100.0; // one percent
    d = ((double)pageStats->totalResponseCount) / d; // percents of total
    [stats setObject:[NSStringClass stringWithFormat:@"%.3f%%", d]
           forKey:@"pageFrequency"];

    
    d = ((double)self->totalResponseSize) / 100.0; // one percent
    d = ((double)pageStats->totalResponseSize) / d; // percents of total
    [stats setObject:[NSStringClass stringWithFormat:@"%.3f%%", d]
           forKey:@"pageDeliveryVolume"];
  }
  
  return stats;
}

- (NSDictionary *)statistics {
  NSMutableDictionary *stats;
  NSDate   *now;
  double   uptime;
  
  stats  = [NSMutableDictionary dictionaryWithCapacity:64];
  now    = [NSDate date];
  uptime = [now timeIntervalSinceDate:self->startTime];
  
  [stats setObject:mkuint(self->totalResponseSize)
         forKey:@"totalResponseSize"];
  [stats setObject:mkuint(self->totalResponseCount)
         forKey:@"totalResponseCount"];
  [stats setObject:mkdbl(self->totalDuration)
         forKey:@"totalDuration"];
  [stats setObject:mkuint(self->pageResponseCount)
         forKey:@"pageResponseCount"];
  if (self->smallestResponseSize >= 0) {
    [stats setObject:mkuint(self->largestResponseSize)
           forKey:@"largestResponseSize"];
    [stats setObject:mkuint(self->smallestResponseSize)
           forKey:@"smallestResponseSize"];
    [stats setObject:mkdbl(self->minimumDuration)
           forKey:@"minimumDuration"];
    [stats setObject:mkdbl(self->maximumDuration)
           forKey:@"maximumDuration"];
  }

  if ((self->totalDuration > 0) && (uptime > 0)) {
    [stats setObject:
             [NSStringClass stringWithFormat:@"%.3f%%",
                         self->totalDuration / (uptime / 100.0)]
           forKey:@"instanceLoad"];
  }
  
  if (self->totalResponseCount > 0) {
    [stats setObject:mkuint(self->totalResponseSize / self->totalResponseCount)
           forKey:@"averageResponseSize"];
    [stats setObject:mkdbl(self->totalDuration / self->totalResponseCount)
           forKey:@"averageDuration"];
  }
  
  [stats setObject:self->startTime forKey:@"instanceStartDate"];
  [stats setObject:now             forKey:@"statisticsDate"];
  [stats setObject:[NSStringClass stringWithFormat:@"%.3f", uptime]
         forKey:@"instanceUptime"];
  [stats setObject:[NSStringClass stringWithFormat:@"%.3f", uptime / 3600.0]
         forKey:@"instanceUptimeInHours"];

  [stats setObject:mkuint(self->zippedResponsesCount)
         forKey:@"numberOfZippedResponses"];
  [stats setObject:mkuint(self->totalZippedSize)
         forKey:@"totalZippedSize"];
  
  /* page statistics */
  {
    NSEnumerator        *pageNames;
    NSString            *pageName;
    NSMutableDictionary *pageStats;

    pageStats = [NSMutableDictionary dictionaryWithCapacity:16];
    pageNames = [self->pageStatistics keyEnumerator];
    while ((pageName = [pageNames nextObject])) {
      NSDictionary *s;

      s = [self statisticsForPageNamed:pageName];
      if (s == nil)
        continue;
      
      [pageStats setObject:s forKey:pageName];
    }
    
    if (pageStats)
      [stats setObject:pageStats forKey:@"pageStatistics"];
  }
  
  return stats;
}

/* recording */

- (void)recordStatisticsForResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  WOComponent    *page;
  unsigned       size;
  NSNumber       *zippedSize;
  NSDate         *requestStartDate;
  NSDate         *now;
  NSTimeInterval duration;
  
  zippedSize = [[_response userInfo] objectForKey:@"WOResponseZippedLength"];
  if (zippedSize) {
    size = [[[_response userInfo] objectForKey:@"WOResponseUnzippedLength"]
	                          unsignedIntValue];
  }
  else
    size = [[_response content] length];
  
  requestStartDate = [[_context request] startDate];
  now = [NSDate date];
  
  duration = (requestStartDate)
    ? [now timeIntervalSinceDate:requestStartDate]
    : 0.0;
  
  self->totalResponseCount++;
  self->totalResponseSize += size;
  self->totalDuration     += duration;
  
  if (self->smallestResponseSize == -1) {
    /* first request */
    self->largestResponseSize  = size;
    self->smallestResponseSize = size;
    self->maximumDuration      = duration;
    self->minimumDuration      = duration;
  }
  else {
    if (size > self->largestResponseSize)  self->largestResponseSize = size;
    if (size < self->smallestResponseSize) self->smallestResponseSize = size;
    if (duration > self->maximumDuration)  self->maximumDuration = duration;
    if (duration < self->minimumDuration)  self->minimumDuration = duration;
  }
  
  if (zippedSize) {
    self->zippedResponsesCount++;
    self->totalZippedSize += [zippedSize unsignedIntValue];
  }
  
  if ((page = [_context page])) {
    _WOPageStats *pageStats;
    
    self->pageResponseCount++;
    
    if (self->pageStatistics == nil)
      self->pageStatistics = [[NSMutableDictionary alloc] initWithCapacity:64];
    
    if ((pageStats = [self->pageStatistics objectForKey:[page name]]) == nil) {
      pageStats = [[[_WOPageStats alloc] init] autorelease];
      pageStats->pageName = [[page name] copy];

      pageStats->largestResponseSize  = size;
      pageStats->smallestResponseSize = size;
      pageStats->maximumDuration      = duration;
      pageStats->minimumDuration      = duration;
      
      [self->pageStatistics setObject:pageStats forKey:pageStats->pageName];
    }
    else {
      if (size > pageStats->largestResponseSize)
        pageStats->largestResponseSize = size;
      if (size < pageStats->smallestResponseSize)
        pageStats->smallestResponseSize = size;
      if (duration > pageStats->maximumDuration)
        pageStats->maximumDuration = duration;
      if (duration < pageStats->minimumDuration)
        pageStats->minimumDuration = duration;
    }
    
    pageStats->totalResponseCount++;
    pageStats->totalResponseSize += size;
    pageStats->totalDuration     += duration;
    
    if (zippedSize) {
      pageStats->zippedResponsesCount++;
      pageStats->totalZippedSize += [zippedSize unsignedIntValue];
    }
  }
}

- (NSString *)descriptionForResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  NSString    *result;
  WOComponent *page;

  if ((page = [_context page]) == nil) {
    return [NSStringClass stringWithFormat:
			    @"<no page generated for context %@>",
			    _context];
  }
  
  result =
    [page respondsToSelector:@selector(descriptionForResponse:inContext:)]
    ? [page descriptionForResponse:_response inContext:_context]
    : [page name];
  return result;
}

/* formatting */

- (NSString *)formatDescription:(NSString *)_description
  forResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  NSMutableString *result;
  WORequest       *request;
  NSString        *remoteHost = @"-";
  NSCalendarDate  *now;
  NSDate          *startDate;
  NSString        *tmp;
  char            buf[64];
  
  request = [_context request];
  result  = [NSMutableString stringWithCapacity:256];
  
  /* remote host and date */

  if ((remoteHost = [request headerForKey:@"x-webobjects-remote-host"]))
    ;
  else if ((remoteHost = [request headerForKey:@"x-webobjects-remote-addr"]))
    ;
  else
    remoteHost = @"-";
  
  now = [NSCalendarDate calendarDate];
  [now setTimeZone:gmt];
  
  [result appendString:remoteHost];
  sprintf(buf, 
#if GS_64BIT_OLD
	  " - - [%02i/%s/%04i:%02i:%02i:%02i GMT] ",
#else
	  " - - [%02li/%s/%04li:%02li:%02li:%02li GMT] ",
#endif
	  [now dayOfMonth], monthAbbr[[now monthOfYear]], 
	  [now yearOfCommonEra],
	  [now hourOfDay], [now minuteOfHour], [now secondOfMinute]);
  tmp = [[NSStringClass alloc] initWithCString:buf];
  [result appendString:tmp];
  [tmp release];
  
  /* request */
  
  [result appendString:@"\""];
  [result appendString:[request method]];
  [result appendString:@" "];
  [result appendString:[request uri]];
  [result appendString:@" "];
  [result appendString:[request httpVersion]];
  [result appendString:@"\" "];

  /* response */
  
  [result appendFormat:@"%i %i",
            [_response status], [[_response content] length]];
  
  if ((startDate = [request startDate]) != nil) {
    NSTimeInterval duration;
    
    duration = [now timeIntervalSinceDate:startDate];
    sprintf(buf, " %.3f", duration);
    tmp = [[NSStringClass alloc] initWithCString:buf];
    [result appendString:tmp];
    [tmp release];
  }
  
  return result;
}

/* NSLocking */

- (void)lock {
  [self->lock lock];
}
- (void)unlock {
  [self->lock unlock];
}

@end /* WOStatisticsStore */

@implementation _WOPageStats

- (id)init {
  self->totalDuration   = 0.0;
  self->minimumDuration = 0.0;
  self->maximumDuration = 0.0;
  return self;
}

- (void)dealloc {
  RELEASE(self->pageName);
  [super dealloc];
}

@end /* _WOPageStats */
