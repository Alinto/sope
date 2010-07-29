/* 
   NSNotificationQueue.m

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
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSThread.h>

#include "PrivateThreadData.h"

/*
 * NSNotificationQueue queue
 */

typedef struct _NSNotificationQueueRegistration {
    struct _NSNotificationQueueRegistration* next;
    struct _NSNotificationQueueRegistration* prev;
    NSNotification* notification;
    id name;
    id object;
    NSArray* modes;
} NSNotificationQueueRegistration;

typedef struct _NSNotificationQueueList {
    struct _NSNotificationQueueRegistration *head;
    struct _NSNotificationQueueRegistration *tail;
} NSNotificationQueueList;

/*
 * Queue functions
 *
 *  Queue             Elem              Elem              Elem
 *    head ---------> prev -----------> prev -----------> prev --> nil
 *            nil <-- next <----------- next <----------- next
 *    tail --------------------------------------------->
 */

static void
remove_from_queue(
    NSNotificationQueueList* queue,
    NSNotificationQueueRegistration* item,
    NSZone* zone)
{
    if (item->prev)
	item->prev->next = item->next;
    else {
	queue->tail = item->next;
	if (item->next)
	    item->next->prev = NULL;
    }
    
    if (item->next)
	item->next->prev = item->prev;
    else {
	queue->head = item->prev;
	if (item->prev)
	    item->prev->next = NULL;
    }
    RELEASE(item->notification);
    RELEASE(item->modes);
    NSZoneFree(zone, item);
}

static void
add_to_queue(
    NSNotificationQueueList *queue,
    NSNotification *notification,
    NSArray *modes,
    NSZone  *zone)
{
    /* note: this is called in UnixSignalHandler (no malloc allowed) */
    // TODO: possibly calls malloc in Unix signal handler
    NSNotificationQueueRegistration *item = 
        NSZoneCalloc(zone, 1, sizeof(NSNotificationQueueRegistration));
    
    item->notification = RETAIN(notification);
    item->name   = [notification notificationName];
    item->object = [notification notificationObject];
    
    /* modes isn't used with sigs */
    item->modes  = [modes copyWithZone:[modes zone]];
    
    item->prev = NULL;
    item->next = queue->tail;
    queue->tail = item;
    if (item->next)
	item->next->prev = item;
    if (!queue->head)
	queue->head = item;
}

/*
 * Notification Queue calss variables
 */

typedef struct _InstanceList {
    struct _InstanceList *next;
    struct _InstanceList *prev;
    id	queue;
} InstanceList;

static BOOL isMultiThreaded = NO;
static InstanceList        *notificationQueues = NULL;
static NSNotificationQueue *defaultQueue = nil;

/*
 * NSNotificationQueue class implementation
 */

@implementation NSNotificationQueue

+ (void)initialize
{
    static BOOL initialized = NO;

    if (!initialized) {
	initialized = YES;
	defaultQueue = [[self alloc] init];
    }
}

+ (void)taskNowMultiThreaded:notification
{
    PrivateThreadData *threadData = [[NSThread currentThread]
                                               _privateThreadData];
    
    [threadData setThreadNotificationQueues:notificationQueues];
    [threadData setDefaultNotificationQueue:defaultQueue];
    notificationQueues = NULL;
    defaultQueue = nil;
    isMultiThreaded = YES;
}

+ (NSNotificationQueue *)defaultQueue
{
    if (isMultiThreaded) {
	return [[[NSThread currentThread] _privateThreadData]
                           defaultNotificationQueue];
    }
    else {
        NSAssert(defaultQueue, @"default queue not setup ...");
	return defaultQueue;
    }
}

- (id)init
{
    NSNotificationCenter *defcenter;

    defcenter = [NSNotificationCenter defaultCenter];
    return [self initWithNotificationCenter:defcenter];
}

- (id)initWithNotificationCenter:(NSNotificationCenter*)notificationCenter
{
    InstanceList *regItem;
    
    self->zone = [self zone];

    // init queue
    self->center = RETAIN(notificationCenter);
    self->asapQueue =
        NSZoneCalloc(self->zone, 1, sizeof(NSNotificationQueueList));
    self->idleQueue =
        NSZoneCalloc(self->zone, 1, sizeof(NSNotificationQueueList));
    
    // insert in global queue list
    regItem = Calloc(1, sizeof(InstanceList));
    regItem->queue = self; /* hh: do not retain ? */
    
    if (isMultiThreaded) {
	PrivateThreadData* threadData = [[NSThread currentThread]
						_privateThreadData];

	regItem->next = [threadData threadNotificationQueues];
	[threadData setThreadNotificationQueues:regItem];
    }
    else {
	regItem->next = notificationQueues;
	notificationQueues = regItem;
    }
    
    return self;
}

- (void)dealloc
{
    NSNotificationQueueRegistration *item;
    InstanceList      *regItem, *theItem;
    PrivateThreadData *threadData = nil;
    InstanceList *queues;

    /* remove from class instances list */
    if (isMultiThreaded) {
	threadData = [[NSThread currentThread] _privateThreadData];
	queues = [threadData threadNotificationQueues];
    }
    else
	queues = notificationQueues;

    if (queues->queue == self) {
	if (isMultiThreaded)
	    [threadData setThreadNotificationQueues:queues->next];
	else
	    notificationQueues = notificationQueues->next;
    }
    else {
	for (regItem=notificationQueues;
	      regItem->next;
	      regItem=regItem->next)
	{
	    if (regItem->next->queue == self) {
		theItem = regItem->next;
		regItem->next = theItem->next;
		lfFree(theItem);
		break;
	    }
	}
    }
    
    /* release self */
    for (item = self->asapQueue->head; item; item=item->prev)
	remove_from_queue(self->asapQueue, item, self->zone);
    NSZoneFree(self->zone, self->asapQueue);

    for (item = self->idleQueue->head; item; item=item->prev)
	remove_from_queue(self->idleQueue, item, self->zone);
    NSZoneFree(self->zone, self->idleQueue);

    RELEASE(self->center);
    [super dealloc];
}

/* Inserting and Removing Notifications From a Queue */

- (void)dequeueNotificationsMatching:(NSNotification *)notification
  coalesceMask:(unsigned int)coalesceMask /* NSNotificationCoalescing */
{
    NSNotificationQueueRegistration* item;
    NSNotificationQueueRegistration* next;
    id name   = [notification notificationName];
    id object = [notification notificationObject];
    
    /* find in ASAP notification in queue */
    for (item = self->asapQueue->tail; item; item=next) {
	next = item->next;
	if ((coalesceMask & NSNotificationCoalescingOnName)
	    && [name isEqual:item->name]) {
	    remove_from_queue(self->asapQueue, item, self->zone);
	    continue;
	}
	if ((coalesceMask & NSNotificationCoalescingOnSender)
	    && (object == item->object)) {
	    remove_from_queue(self->asapQueue, item, self->zone);
	    continue;
	}
    }
    
    // find in idle notification in queue
    for (item = self->idleQueue->tail; item; item=next) {
	next = item->next;
	if ((coalesceMask & NSNotificationCoalescingOnName)
	    && [name isEqual:item->name]) {
	    remove_from_queue(self->asapQueue, item, self->zone);
	    continue;
	}
	if ((coalesceMask & NSNotificationCoalescingOnSender)
	    && (object == item->object)) {
	    remove_from_queue(self->asapQueue, item, self->zone);
	    continue;
	}
    }
}

- (BOOL)postNotification:(NSNotification *)notification
  forModes:(NSArray *)modes
{
    BOOL     ok = NO;
    NSString *mode = [[NSRunLoop currentRunLoop] currentMode];
    
    /* check to see if run loop is in a valid mode */
    if (mode == nil || modes == nil)
	ok = YES;
    else {
	int i;
	
	for (i = [modes count]-1; i >= 0; i--) {
	    if ([mode isEqual:[modes objectAtIndex:i]]) {
		ok = YES;
		break;
	    }
	}
    }
    
    // if mode is valid then post
    if (ok)
	[self->center postNotification:notification];

    return ok;
}

- (void)enqueueNotification:(NSNotification *)notification
  postingStyle:(NSPostingStyle)postingStyle	
{
    [self enqueueNotification:notification
          postingStyle:postingStyle
          coalesceMask:(NSNotificationCoalescingOnName + 
                        NSNotificationCoalescingOnSender)
          forModes:nil];
}

- (void)enqueueNotification:(NSNotification *)notification
  postingStyle:(NSPostingStyle)postingStyle
  coalesceMask:(unsigned int)coalesceMask /* NSNotificationCoalescing */
  forModes:(NSArray *)modes
{
    /* note: this is called in UnixSignalHandler (no malloc allowed) */
    if (coalesceMask != NSNotificationNoCoalescing) {
	[self dequeueNotificationsMatching:notification
              coalesceMask:coalesceMask];
    }
    
    NSAssert(notification, @"missing notification ...");
    
    switch (postingStyle) {
	case NSPostNow:
		[self postNotification:notification forModes:modes];
		break;
	case NSPostASAP:
		add_to_queue(self->asapQueue, notification, modes, self->zone);
		break;
	case NSPostWhenIdle:
		add_to_queue(self->idleQueue, notification, modes, self->zone);
		break;
    }
}

/*
 * NotificationQueue internals
 */

+ (void)runLoopIdle
{
    InstanceList *item, *queues;

    if (isMultiThreaded)
	queues = [[[NSThread currentThread] _privateThreadData]
			threadNotificationQueues];
    else
	queues = notificationQueues;

    for (item = queues; item; item = item->next)
	[item->queue notifyIdle];
}

+ (void)runLoopASAP
{
    InstanceList *item, *queues;
    
    if (isMultiThreaded) {
	queues = [[[NSThread currentThread] _privateThreadData]
                             threadNotificationQueues];
    }
    else
	queues = notificationQueues;

    //printf("RUNNING LOOP ASAP ...\n");
    for (item = queues; item; item = item->next) {
        //printf("  RUNNING ITEM ...\n");
	[item->queue notifyASAP];
    }
}

- (void)notifyIdle
{
    /* post next IDLE notification in queue */
    if (self->idleQueue->head) {
	if ([self postNotification:self->idleQueue->head->notification 
                  forModes:self->idleQueue->head->modes]) {
	    remove_from_queue(self->idleQueue, self->idleQueue->head,
                              self->zone);
        }
    }
}

- (void)notifyASAP
{
    /* post all ASAP notifications in queue */
    while (self->asapQueue->head) {
        struct _NSNotificationQueueRegistration *asapHead;
        BOOL ok;

        asapHead = self->asapQueue->head;

        ok = [self postNotification:asapHead->notification
                   forModes:asapHead->modes];
        
	if (ok)
	    remove_from_queue(self->asapQueue, asapHead, self->zone);
    }
}

@end /* NSNotificationQueue */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

