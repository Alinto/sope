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

#include "EOObserver.h"
#include "common.h"

// THREAD, MT

typedef struct _EOObserverList {
  struct _EOObserverList *next;
  id<EOObserving>        observer;
  void                   (*notify)(id, SEL, id);
} EOObserverList;

static void     mapValRetain(NSMapTable *self, const void *_value);
static void     mapValRelease(NSMapTable *self, void *_value);
static NSString *mapDescribe(NSMapTable *self, const void *_value);

const NSMapTableValueCallBacks EOObserverListMapValueCallBacks = {
  (void (*)(NSMapTable *, const void *))mapValRetain,
  (void (*)(NSMapTable *, void *))mapValRelease,
  (NSString *(*)(NSMapTable *, const void *))mapDescribe
};

@implementation NSObject(EOObserver)

- (void)willChange {
  static Class EOObserverCenterClass = Nil;
  if (EOObserverCenterClass == Nil)
    EOObserverCenterClass = [EOObserverCenter class];

  [EOObserverCenterClass notifyObserversObjectWillChange:self];
}

@end /* NSObject(EOObserver) */

@implementation EOObserverCenter

static unsigned       observerNotificationSuppressCount = 0;
static EOObserverList *omniscientObservers = NULL;
static NSMapTable     *objectToObservers   = NULL;

+ (void)initialize {
  if (objectToObservers == NULL) {
    objectToObservers = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                         EOObserverListMapValueCallBacks,
                                         256);
  }
}

+ (void)notifyObserversObjectWillChange:(id)_object {
  static id lastObject = nil;
  register EOObserverList *l;

  /* check if notifications are suppressed */
  if (observerNotificationSuppressCount > 0)
    return;
  
  /* compress notifications for the same object */
  if (_object == lastObject)
    return;

  /* notify usual observers */

  for (l = NSMapGet(objectToObservers, _object); l != NULL; l = l->next) {
    if (l->notify)
      l->notify(l->observer, @selector(objectWillChange:), _object);
    else
      [l->observer objectWillChange:_object];
  }
  
  /* notify omniscient observers */
  
  for (l = omniscientObservers; l != NULL; l = l->next) {
    if (l->notify)
      l->notify(l->observer, @selector(objectWillChange:), _object);
    else
      [l->observer objectWillChange:_object];
  }
}

+ (void)addObserver:(id<EOObserving>)_observer forObject:(id)_object {
  register EOObserverList *l, *nl;
  
  if ((l = NSMapGet(objectToObservers, _object))) {
    /* check whether the observer is already registered */
    
    for (nl = l; nl != NULL; nl = nl->next) {
      if (nl->observer == _object)
        return;
    }
  }

#if NeXT_RUNTIME
  nl = malloc(sizeof(EOObserverList));
#else  
  nl = objc_malloc(sizeof(EOObserverList));
#endif
  nl->observer = [_observer retain];
  nl->notify   = (void*)
    [(id)_observer methodForSelector:@selector(objectWillChange:)];

  if (l == NULL) {
    /* this is the first observer defined */
    nl->next = NULL;
    NSMapInsert(objectToObservers, _object, nl);
  }
  else {
    /*
      insert at second position (so that we don't need to remove/add the new
      entry in table or traverse the list to the end)
    */
    nl->next = l->next;
    l->next = nl;
  }
}

+ (void)removeObserver:(id<EOObserving>)_observer forObject:(id)_object {
  register EOObserverList *l, *ll, *first;

  if ((first = NSMapGet(objectToObservers, _object)) == NULL)
    /* no observers registered for object */
    return;

  l  = first;
  ll = NULL;
  while (l) {
    if (l->observer == _observer) {
      /* found matching list entry */
      if (l != first) {
        /* entry is not the first entry */
        ll->next = l->next;
        [l->observer release];
#if NeXT_RUNTIME
        free(l);
#else    
        objc_free(l);
#endif
        break;
      }
      else if (l->next) {
        /*
          entry is the first entry, but there are more than one entries.
          In this case we copy the second to the first and remove the second,
          this way we save removing/inserting in the hash table.
        */
        [l->observer release];
        ll = l->next;
        l->observer = ll->observer;
        l->notify   = ll->notify;
        l->next     = ll->next;
#if NeXT_RUNTIME
        free(ll);
#else    
        objc_free(ll);
#endif
        break;
      }
      else {
        /* entry is the lone entry */
        NSMapRemove(objectToObservers, _object);
        [l->observer release];
#if NeXT_RUNTIME
        free(l);
#else    
        objc_free(l);
#endif
        break;
      }
    }
    
    ll = l;
    l = ll->next;
  }
}

+ (NSArray *)observersForObject:(id)_object {
  EOObserverList *observers;
  NSMutableArray *result;
  
  if ((observers = NSMapGet(objectToObservers, _object)) == NULL)
    return [NSArray array];
  
  result = [NSMutableArray arrayWithCapacity:16];
  while ((observers)) {
    if (observers->observer)
      [result addObject:observers->observer];
    observers = observers->next;
  }
  
  return [[result copy] autorelease];
}

+ (id)observerForObject:(id)_object ofClass:(Class)_targetClass {
  register EOObserverList *observers;
  
  if ((observers = NSMapGet(objectToObservers, _object)) == NULL)
    return nil;

  while ((observers)) {
    if ([observers->observer class] == _targetClass)
      return observers->observer;
    observers = observers->next;
  }
  return nil;
}

+ (void)addOmniscientObserver:(id<EOObserving>)_observer {
  EOObserverList *l;
  
  /* first check whether we already added this observer to the list */
  
  for (l = omniscientObservers; l != NULL; l = l->next) {
    if (l->observer == _observer)
      return;
  }

#if NeXT_RUNTIME
  l = malloc(sizeof(EOObserverList));
#else  
  l = objc_malloc(sizeof(EOObserverList));
#endif
  l->next     = omniscientObservers;
  l->observer = [_observer retain];
  l->notify   = (void*)[(id)_observer methodForSelector:@selector(willChange:)];

  omniscientObservers = l;
}
+ (void)removeOmniscientObserver:(id<EOObserving>)_observer {
  EOObserverList *l, *ll;
  
  /* first check whether we already added this observer to the list */
  
  for (l = omniscientObservers, ll = NULL; l != NULL; ) {
    if (l->observer == _observer) {
      /* matched */
      if (ll == NULL)
        omniscientObservers = l->next;
      else
        ll->next = l->next;

      [l->observer release];
      objc_free(l);
      return;
    }

    ll = l;
    l = ll->next;
  }
}

/* suppressing notifications */

+ (void)suppressObserverNotification {
  observerNotificationSuppressCount++;
}
+ (void)enableObserverNotification {
  observerNotificationSuppressCount--;
}

+ (unsigned)observerNotificationSuppressCount {
  return observerNotificationSuppressCount;
}

@end /* EOObserverCenter */

@implementation EODelayedObserverQueue

static EODelayedObserverQueue *defaultQueue = nil;

+ (EODelayedObserverQueue *)defaultObserverQueue {
  if (defaultQueue == nil)
    defaultQueue = [[EODelayedObserverQueue alloc] init];
  return defaultQueue;
}

- (id)init {
  [[NSNotificationCenter defaultCenter]
                         addObserver:self selector:@selector(_notify:)
                         name:@"EODelayedNotify" object:self];
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->runLoopModes release];
  [super dealloc];
}

/* accessors */

- (void)setRunLoopModes:(NSArray *)_modes {
  ASSIGN(self->runLoopModes, _modes);
}
- (NSArray *)runLoopModes {
  return self->runLoopModes;
}

/* single queue */

static inline void _enqueue(EODelayedObserverQueue *self,
                            EODelayedObserver **list,
                            EODelayedObserver *newEntry)
{
  if (*list == nil) {
    /* first entry in this list */
    *list = [newEntry retain];
  }
  else {
    EODelayedObserver *e, *le;

    for (e = *list, le = NULL; e != NULL; e = e->next) {
      if (e == newEntry) {
        /* already in queue */
        return;
      }
      le = e;
    }
    le->next = [e retain];
    e->next  = NULL;
  }
}
static inline void _dequeue(EODelayedObserverQueue *self,
                            EODelayedObserver **list,
                            EODelayedObserver *entry)
{
  EODelayedObserver *e, *le;

  for (e = *list, le = NULL; e != NULL; e = e->next) {
    if (e == entry) {
      /* found entry */
      le->next = e->next;
      [e release];
      return;
    }
    le = e;
  }
}

static inline void _notify(EODelayedObserverQueue *self, EODelayedObserver *list)
{
  while (list) {
    [list subjectChanged];
    list = list->next;
  }
}

/* managing queue */

- (void)enqueueObserver:(EODelayedObserver *)_observer {
  if (_observer == nil) return;
  
  _enqueue(self, &(self->queues[[_observer priority]]), _observer);

  if (!self->hasObservers) {
    /* register for ASAP notification */
    NSNotification *notification;
    
    notification = [NSNotification notificationWithName:@"EODelayedNotify"
                                   object:self];
    
    [[NSNotificationQueue defaultQueue]
                          enqueueNotification:notification
                          postingStyle:NSPostASAP
                          coalesceMask:NSNotificationCoalescingOnSender
                          forModes:[self runLoopModes]];
    
    self->hasObservers = YES;
  }
}
- (void)dequeueObserver:(EODelayedObserver *)_observer {
  if (_observer == nil) return;
  
  _dequeue(self, &(self->queues[[_observer priority]]), _observer);
}

/* notification */

- (void)notifyObserversUpToPriority:(EOObserverPriority)_lastPriority {
  unsigned i;
  
  for (i = 0; i < _lastPriority; i++)
    _notify(self, self->queues[i]);
}

- (void)_notify:(NSNotification *)_notification {
  [self notifyObserversUpToPriority:EOObserverPrioritySixth];
}

@end /* EODelayedObserverQueue */

@implementation EODelayedObserver

/* accessors */

- (EOObserverPriority)priority {
  return EOObserverPriorityThird;
}

- (EODelayedObserverQueue *)observerQueue {
  return [EODelayedObserverQueue defaultObserverQueue];
}

/* notifications */

- (void)subjectChanged {
  [self doesNotRecognizeSelector:_cmd];
}

- (void)objectWillChange:(id)_object {
  [[self observerQueue] enqueueObserver:self];
}

- (void)discardPendingNotification {
  [[self observerQueue] dequeueObserver:self];
}

@end /* EODelayedObserver */

@implementation EOObserverProxy

- (id)initWithTarget:(id)_target action:(SEL)_action
  priority:(EOObserverPriority)_priority
{
  if ((self = [super init])) {
    self->target   = [_target retain];
    self->action   = _action;
    self->priority = _priority;
  }
  return self;
}
- (id)init {
  return [self initWithTarget:nil action:NULL priority:EOObserverPriorityThird];
}

- (void)dealloc {
  [self->target release];
  [super dealloc];
}

/* accessors */

- (EOObserverPriority)priority {
  return self->priority;
}

/* notifications */

- (void)subjectChanged {
  [self->target performSelector:self->action withObject:self];
}

@end /* EOObserverProxy */

/* value functions for mapping table */

static void mapValRetain(NSMapTable *self, const void *_value) {
  /* do nothing */
}
static void mapValRelease(NSMapTable *self, void *_value) {
  /* do nothing */
}

static NSString *mapDescribe(NSMapTable *self, const void *_value) {
  return @"";
}
