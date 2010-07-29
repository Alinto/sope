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

#ifndef __EOControl_EOObserver_H__
#define __EOControl_EOObserver_H__

#import <Foundation/NSObject.h>

@class NSArray;

@protocol EOObserving < NSObject >

- (void)objectWillChange:(id)_object;

@end

@interface NSObject(EOObserver)

- (void)willChange;

@end

/*
  Note that -addObserver/-removeObserver methods do *not* nest !
  Suppression methods do nest.
*/

@interface EOObserverCenter : NSObject

+ (void)notifyObserversObjectWillChange:(id)_object;

+ (void)addObserver:(id<EOObserving>)_observer forObject:(id)_object;
+ (void)removeObserver:(id<EOObserving>)_observer forObject:(id)_object;
+ (void)addOmniscientObserver:(id<EOObserving>)_observer;
+ (void)removeOmniscientObserver:(id<EOObserving>)_observer;

+ (NSArray *)observersForObject:(id)_object;
+ (id)observerForObject:(id)_object ofClass:(Class)_targetClass;

/* suppressing notifications */

+ (void)suppressObserverNotification;
+ (void)enableObserverNotification;
+ (unsigned)observerNotificationSuppressCount;

@end

/* asynchronous observing */

typedef enum {
  EOObserverPriorityImmediate,
  EOObserverPriorityFirst,
  EOObserverPrioritySecond,
  EOObserverPriorityThird,
  EOObserverPriorityFourth,
  EOObserverPriorityFifth,
  EOObserverPrioritySixth,
  EOObserverPriorityLater
} EOObserverPriority;

@class EODelayedObserver;

@interface EODelayedObserverQueue : NSObject
{
@protected
  EODelayedObserver *queues[8];
  NSArray           *runLoopModes;
  BOOL              hasObservers;
}

+ (EODelayedObserverQueue *)defaultObserverQueue;

/* accessors */

- (void)setRunLoopModes:(NSArray *)_modes;
- (NSArray *)runLoopModes;

/* managing queue */

- (void)enqueueObserver:(EODelayedObserver *)_observer;
- (void)dequeueObserver:(EODelayedObserver *)_observer;

/* notification */

- (void)notifyObserversUpToPriority:(EOObserverPriority)_lastPriority;

@end

@interface EODelayedObserver : NSObject < EOObserving >
{
@public
  EODelayedObserver *next; /* for access by queue */
}

/* accessors */

- (EOObserverPriority)priority;
- (EODelayedObserverQueue *)observerQueue;

/* notifications */

- (void)subjectChanged;
- (void)discardPendingNotification;

@end

@interface EOObserverProxy : EODelayedObserver
{
@protected
  EOObserverPriority priority;
  id  target;
  SEL action;
}

- (id)initWithTarget:(id)_target action:(SEL)_action
  priority:(EOObserverPriority)_priority;

@end

#endif /* __EOControl_EOObserver_H__ */
