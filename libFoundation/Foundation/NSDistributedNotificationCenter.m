/* 
   NSDistributedNotification.m

   Copyright (C) 1999 MDlink online service center, Helge Hess
   All rights reserved.
   
   Author: Helge Hess <helge.hess@mdlink.de>

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

#include "NSDistributedNotificationCenter.h"

NSString *NSLocalNotificationCenterType = @"NSLocalNotificationCenter";

// MT
static NSDistributedNotificationCenter *defaultCenter = nil;

@implementation NSDistributedNotificationCenter

+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSString *)_type
{
    if ([_type isEqualToString:NSLocalNotificationCenterType]) {
        if (defaultCenter == nil)
            defaultCenter = [[self alloc] init];
        return defaultCenter;
    }
    else
        return nil;
}

+ (NSNotificationCenter *)defaultCenter
{
    return [self notificationCenterForType:NSLocalNotificationCenterType];
}

/* observers */

- (void)addObserver:(id)_observer selector:(SEL)_selector
  name:(NSString *)_notificationName object:(NSString *)_object
  suspensionBehavior:(NSNotificationSuspensionBehavior)_suspbehave
{
    [self notImplemented:_cmd];
}

- (void)addObserver:(id)_observer selector:(SEL)_selector
  name:(NSString *)_notificationName object:(id)_object
{
    [self addObserver:_object selector:_selector
          name:_notificationName object:_object
          suspensionBehavior:NSNotificationSuspensionBehaviorCoalesce];
}

- (void)removeObserver:(id)observer 
  name:(NSString*)notificationName object:(id)object
{
    [self notImplemented:_cmd];
}

/* posting */

- (void)postNotificationName:(NSString *)_name object:(id)_object
  userInfo:(NSDictionary *)_ui deliverImmediatly:(BOOL)_flag
{
    [self notImplemented:_cmd];
}

- (void)postNotificationName:(NSString *)_name object:(id)_object
{
    [self postNotificationName:_name
          object:_object
          userInfo:nil
          deliverImmediatly:NO];
}

- (void)postNotificationName:(NSString *)_name object:(id)_object
  userInfo:(NSDictionary *)_userInfo
{
    [self postNotificationName:_name
          object:_object
          userInfo:_userInfo
          deliverImmediatly:NO];
}

- (void)postNotification:(NSNotification *)_notification
{
    [self postNotificationName:[_notification name]
          object:[_notification object]
          userInfo:[_notification userInfo]
          deliverImmediatly:NO];
}

/* suspension */

- (void)setSuspended:(BOOL)_flag
{
}
- (BOOL)suspended
{
    return NO;
}

@end /* NSDistributedNotificationCenter */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
