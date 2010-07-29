/* 
   NSNotificationCenter.m

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
#include <Foundation/NSNotification.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSThread.h>

#include <extensions/objc-runtime.h>
#include <extensions/NSException.h>
#include <extensions/NSException.h>
#include <extensions/GarbageCollector.h>
#include <extensions/exceptions/GeneralExceptions.h>

#include "PrivateThreadData.h"

#define DEFAULT_CAPACITY 32

#define FREE_UNUSED_OBSERVED_OBJECTS 1
/*
 * Objects/selectors pair used in sets
 */

@interface NSNotificationListItem : NSObject
{
@public
    /* weak */ id  observer;	// observer that will receive selector
    SEL selector;	        // is a postNotification:
    NSNotificationListItem* next; // this is needed for keeping a
                                  // linked list of items to be removed
}
- (id)initWithObject:(id)anObserver selector:(SEL)aSelector;
- (BOOL)isEqual:(id)_other;
- (unsigned)hash;
- (void)postNotification:(NSNotification*)notification;
@end

@implementation NSNotificationListItem

#if LIB_FOUNDATION_BOEHM_GC

+ (void)initialize
{
  class_ivar_set_gcinvisible (self, "observer", YES);
}

+ (BOOL)requiresTypedMemory
{
    return YES;
}

#endif

- (id)initWithObject:(id)anObserver selector:(SEL)aSelector
{
    self->observer = anObserver;
    self->selector = aSelector;
    return self;
}

- (BOOL)isEqual:(id)other
{
    if ([other isKindOfClass:[NSNotificationListItem class]]) {
	NSNotificationListItem *obj;
        obj = other;
	return (observer == obj->observer) && SEL_EQ(selector, obj->selector);
    }
    
    return NO;
}

- (unsigned)hash
{
    return ((long)observer >> 4) + 
	   __NSHashCString(NULL, sel_get_name(selector));
}

- (void)postNotification:(NSNotification*)notification
{
    [self->observer performSelector:self->selector withObject:notification];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ 0x%p: observer=%@ sel=%@>",
                       NSStringFromClass([self class]), self,
                       self->observer, NSStringFromSelector(self->selector)
                     ];
}

@end /* NSNotificationListItem */

/*
 * Register for objects to observer mapping
 */

@interface NSNotificationObserverRegister : NSObject
{
    NSHashTable *observerItems;
@public
    void (*addObserver)(id,SEL,id,SEL);
    void (*remObserver)(id,SEL,id);
}
- (id)init;
- (unsigned int)count;
- (void)addObjectsToList:(NSMutableArray*)list;
- (void)addObserver:(id)observer selector:(SEL)selector;
- (void)removeObserver:(id)observer;
@end

@implementation NSNotificationObserverRegister

- (id)init
{
    self->observerItems =
        NSCreateHashTable(NSObjectHashCallBacks, DEFAULT_CAPACITY);
    self->addObserver = (void *)
        [self methodForSelector:@selector(addObserver:selector:)];
    self->remObserver = (void *)
        [self methodForSelector:@selector(removeObserver:)];
    return self;
}

- (void)dealloc
{
    NSFreeHashTable(self->observerItems);
    [super dealloc];
}

- (unsigned int)count
{
    return NSCountHashTable(self->observerItems);
}

- (void)addObjectsToList:(NSMutableArray *)list
{
    id reg;
    void (*addObj)(id, SEL, id);
    NSHashEnumerator itemsEnum = NSEnumerateHashTable(self->observerItems);

    if (list == nil) return;
    addObj = (void *)[list methodForSelector:@selector(addObject:)];
    
    while((reg = (id)NSNextHashEnumeratorItem(&itemsEnum)))
        addObj(list, @selector(addObject:), reg);
}

- (void)addObserver:(id)observer selector:(SEL)selector
{
    NSNotificationListItem *reg;
    
    reg = [[NSNotificationListItem alloc]
                                   initWithObject:observer selector:selector];
    NSHashInsertIfAbsent(self->observerItems, reg);
    RELEASE(reg);
}

- (void)removeObserver:(id)observer
{
    NSNotificationListItem *listItem = nil;
    NSNotificationListItem *reg;
    NSHashEnumerator       itemsEnum;
    
    itemsEnum = NSEnumerateHashTable(self->observerItems);
    
    while ((reg = (id)NSNextHashEnumeratorItem(&itemsEnum))) {
      if (reg->observer == observer) {
	/* Add 'reg' to the linked list of ListItems. We use this schema here
	   to avoid allocating anything, this can trigger finalization calls
	   in the case of Boehm's GC. */
	reg->next = listItem;
	listItem = reg;
      }
    }
    while (listItem) {
	NSHashRemove(self->observerItems, listItem);
	listItem = listItem->next;
    }
}

@end /* NSNotificationObserverRegister */

/*
 * Register for objects to observer mapping
 */

@interface NSNotificationObjectRegister : NSObject
{
    /* key is the object, value is an NSNotificationObserverRegister */
    NSMapTable                     *objectObservers;
    NSNotificationObserverRegister *nilObjectObservers;
}

- (id)init;
- (NSArray *)listToNotifyForObject:(id)object;
- (void)addObserver:(id)observer selector:(SEL)selector object:(id)object;
- (void)removeObserver:(id)observer object:(id)object;
- (void)removeObserver:(id)observer;

#if LIB_FOUNDATION_BOEHM_GC
- (void)removeObject:(id)object;
#endif

@end

@implementation NSNotificationObjectRegister

- (id)init
{
#if LIB_FOUNDATION_BOEHM_GC
    self->objectObservers = NSCreateMapTableInvisibleKeysOrValues
	(NSNonRetainedObjectMapKeyCallBacks,
	 NSNonRetainedObjectMapValueCallBacks,
	 DEFAULT_CAPACITY,
	 YES, NO);
#else
    self->objectObservers =
        NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                         NSObjectMapValueCallBacks,
                         DEFAULT_CAPACITY);
#endif
    self->nilObjectObservers =
        [[NSNotificationObserverRegister allocWithZone:[self zone]] init];
    return self;
}

- (void)dealloc
{
    NSFreeMapTable(self->objectObservers);
    RELEASE(self->nilObjectObservers);
    [super dealloc];
}

- (NSArray *)listToNotifyForObject:(id)object
{
    NSNotificationObserverRegister *reg = nil;
    int count;
    id  list;
    
    if (object)
	reg = (id)NSMapGet(self->objectObservers, object);
    
    count = [reg count] + [nilObjectObservers count];
    list  = [[NSMutableArray alloc] initWithCapacity:count];
    
    [reg addObjectsToList:list];
    [nilObjectObservers addObjectsToList:list];
    
    return AUTORELEASE(list);
}

- (void)addObserver:(id)observer selector:(SEL)selector object:(id)object
{
    NSNotificationObserverRegister *reg;
    
    if (object) {
	reg = (id)NSMapGet(self->objectObservers, object);
	if (reg == nil) {
	    reg = [[NSNotificationObserverRegister alloc] init];
	    NSMapInsert(objectObservers, object, reg);
            RELEASE(reg);
	}
    }
    else
	reg = nilObjectObservers;

    reg->addObserver(reg, @selector(addObserver:selector:),
                     observer, selector);
}

- (void)removeObserver:(id)observer object:(id)object
{
    NSNotificationObserverRegister *reg;
    
    reg = (object)
        ? NSMapGet(self->objectObservers, object)
        : nilObjectObservers;
    
    if (reg) reg->remObserver(reg, @selector(removeObserver:), observer);

#if FREE_UNUSED_OBSERVED_OBJECTS    
    if (![reg count]) {
        NSMapRemove(self->objectObservers, object);
    }
#endif
}

- (void)removeObserver:(id)observer
{
    id obj;
    NSNotificationObserverRegister *reg;
    NSMapEnumerator regEnum;
#if FREE_UNUSED_OBSERVED_OBJECTS    
    id  *obj2Rm;
    int obj2RmCnt;
    id  z;

    z         = [self zone];
    obj2Rm    = NSZoneCalloc(z, NSCountMapTable(self->objectObservers) + 1,
                          sizeof(id));
    obj2RmCnt = 0;
#endif
    
    regEnum   = NSEnumerateMapTable(self->objectObservers);

    while (NSNextMapEnumeratorPair(&regEnum, (void*)&obj, (void*)&reg)) {
	reg->remObserver(reg, @selector(removeObserver:),observer);
#if FREE_UNUSED_OBSERVED_OBJECTS
        if (![reg count]) {
            obj2Rm[obj2RmCnt++] = obj;
        }
#endif        
    }
#if FREE_UNUSED_OBSERVED_OBJECTS
    while (obj2RmCnt) {
        NSMapRemove(self->objectObservers, obj2Rm[--obj2RmCnt]);
    }
    NSZoneFree(z, obj2Rm); obj2Rm = NULL;
#endif
    
    nilObjectObservers->remObserver(nilObjectObservers,
                                    @selector(removeObserver:), observer);
}

#if LIB_FOUNDATION_BOEHM_GC
- (void)removeObject:(id)object
{
    NSMapRemove (self->objectObservers, object);
}
#endif

@end /* NSNotificationObjectRegister */

/*
 * NSNotificationCenter	
 */

static NSNotificationCenter *defaultCenter = nil;
static BOOL isMultiThreaded = NO;

@implementation NSNotificationCenter 

/* Class methods */

+ (void)initialize
{
    static BOOL initialized = NO;

    if (!initialized) {
	initialized = YES;
	defaultCenter = [self alloc];
	[defaultCenter init];
    }
}

+ (NSNotificationCenter*)defaultCenter
{
    if (isMultiThreaded)
	return [[[NSThread currentThread] _privateThreadData]
		    defaultNotificationCenter];
    else
	return defaultCenter;
}

+ (void)taskNowMultiThreaded:notification
{
    PrivateThreadData* threadData = [[NSThread currentThread]
						_privateThreadData];

    [threadData setDefaultNotificationCenter:defaultCenter];
    defaultCenter = nil;
    isMultiThreaded = YES;
}

/* Init/dealloc */

- (id)init
{
#if LIB_FOUNDATION_BOEHM_GC
    nameToObjects = NSCreateMapTable  (NSNonRetainedObjectMapKeyCallBacks,
                                       NSNonOwnedPointerMapValueCallBacks,
                                       119);
#else
    nameToObjects = NSCreateMapTable (NSObjectMapKeyCallBacks,
				      NSObjectMapValueCallBacks,
				      119);
#endif
    nullNameToObjects = [NSNotificationObjectRegister new];
    return self;
}

- (void)dealloc
{
    NSFreeMapTable (nameToObjects);
    RELEASE(nullNameToObjects);
    [super dealloc];
}

/* Register && post notifications */
    
- (void)postNotification:(NSNotification *)notification
{
    NSArray *fromName;
    NSArray *fromNull;
    NSNotificationObjectRegister* reg;
    id name, object;

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector denyGarbageCollection];
#endif
    
    name   = [notification notificationName];
    object = [notification notificationObject];

    if (name == nil) {
	[[[InvalidArgumentException alloc]
	    initWithFormat:@"`nil' notification name in postNotification:"] 
            raise];
    }
    
    // get objects to notify with registered notification name
    reg      = NSMapGet (nameToObjects, name);
    fromName = [reg listToNotifyForObject:object];
    
    // get objects to notify with no notification name
    fromNull = [nullNameToObjects listToNotifyForObject:object];

    // send notifications
    [fromName makeObjectsPerform:@selector(postNotification:)
	withObject:notification];
    [fromNull makeObjectsPerform:@selector(postNotification:)
	withObject:notification];
    
#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector allowGarbageCollection];
#endif
}

- (void)addObserver:(id)observer selector:(SEL)selector 
  name:(NSString *)notificationName object:(id)object
{
    NSNotificationObjectRegister* reg;

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector denyGarbageCollection];
#endif
    
    if (notificationName == nil)
	reg = nullNameToObjects;
    else {
	notificationName = AUTORELEASE([notificationName copy]);
	reg = NSMapGet (nameToObjects, notificationName);
	if (!reg) {
	    reg = AUTORELEASE([[NSNotificationObjectRegister alloc] init]);
	    NSMapInsert (nameToObjects, notificationName, reg);
	}
    }
    [reg addObserver:observer selector:selector object:object];

#if LIB_FOUNDATION_BOEHM_GC
    if (object) {
        [GarbageCollector registerForFinalizationObserver:self
			  selector:@selector(_objectWillFinalize:)
			  object:object];
    }

    [GarbageCollector registerForFinalizationObserver:self
		      selector:@selector(_observerWillFinalize:)
		      object:observer];

    [GarbageCollector allowGarbageCollection];
#endif
}

- (void)removeObserver:(id)observer 
  name:(NSString*)notificationName object:(id)object
{
    NSNotificationObjectRegister *reg;

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector denyGarbageCollection];
#endif
    
    reg = (notificationName == nil)
	? nullNameToObjects
	: NSMapGet (nameToObjects, notificationName);
    
    [reg removeObserver:observer object:object];

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector allowGarbageCollection];
#endif
}

- (void)removeObserver:(id)observer
{
    id                           name;
    NSMapEnumerator              enumerator;
    NSNotificationObjectRegister *reg;

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector denyGarbageCollection];
#endif
    
    enumerator = NSEnumerateMapTable(self->nameToObjects);

    while (NSNextMapEnumeratorPair(&enumerator, (void*)&name, (void*)&reg))
	[reg removeObserver:observer];

    [nullNameToObjects removeObserver:observer];

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector allowGarbageCollection];
#endif
}

#if LIB_FOUNDATION_BOEHM_GC
- (void)removeObject:object
{
    id                           name;
    NSMapEnumerator              enumerator;
    NSNotificationObjectRegister *reg;

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector denyGarbageCollection];
#endif
    
    enumerator = NSEnumerateMapTable (nameToObjects);

    while (NSNextMapEnumeratorPair (&enumerator, (void*)&name, (void*)&reg))
	[reg removeObject:object];

    [nullNameToObjects removeObject:object];

#if LIB_FOUNDATION_BOEHM_GC
    [GarbageCollector allowGarbageCollection];
#endif
}

- (void)_objectWillFinalize:(id)object
{
#if 0
  printf ("NSNotificationCenter _objectWillFinalize %lu\n",
          (unsigned long)object);
#endif
  [self removeObject:object];
}

- (void)_observerWillFinalize:(id)observer
{
#if 0
  printf ("NSNotificationCenter _observerWillFinalize: %lu\n",
          (unsigned long)observer);
#endif
  [self removeObserver:observer];
}
#endif

- (void)postNotificationName:(NSString*)notificationName object:object
{
    id notification;

    notification = [[NSNotification alloc] initWithName:notificationName
					   object:object
					   userInfo:nil];
    [self postNotification:notification];
    RELEASE(notification);
}

- (void)postNotificationName:(NSString*)notificationName object:object
  userInfo:(NSDictionary*)userInfo;
{
    id notification;

    notification = [[NSNotification alloc] initWithName:notificationName
					   object:object
					   userInfo:userInfo];
    [self postNotification:notification];
    RELEASE(notification);
}

@end /* NSNotificationCenter */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
