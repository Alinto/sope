/* 
   GarbageCollector.m

   Copyright (C) 1995-1998 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and
   its documentation for any purpose and without fee is hereby
   granted, provided that the above copyright notice appear in all
   copies and that both that copyright notice and this permission
   notice appear in supporting documentation.

   We disclaim all warranties with regard to this software, including
   all implied warranties of merchantability and fitness, in no event
   shall we be liable for any special, indirect or consequential
   damages or any damages whatsoever resulting from loss of use, data
   or profits, whether in an action of contract, negligence or other
   tortious action, arising out of or in connection with the use or
   performance of this software.  */

#include <Foundation/common.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSUtilities.h>
#include <extensions/objc-runtime.h>
#include <extensions/GCObject.h>
#include <extensions/GarbageCollector.h>

#if LIB_FOUNDATION_BOEHM_GC
# include <gc.h>
# include <gc_typed.h>
#endif

static BOOL isGarbageCollecting = NO;

#if LIB_FOUNDATION_BOEHM_GC
BOOL _usesBoehmGC = YES;
static GC_descr nodeDescriptor1;
static GC_descr nodeDescriptor2;
#else
BOOL _usesBoehmGC = NO;
#endif

extern NSRecursiveLock* libFoundationLock;
extern Class __freedObjectClass;


/* Stuff used by the garbage collector based on reference counting. */

@interface __DummyGCObject : GCObject
@end

@implementation __DummyGCObject

+ allocWithZone:(NSZone*)zone
{
    return NSAllocateObject(self, 0, zone);
}

- (void)dealloc
{
    /* this is to please gcc 4.1 which otherwise issues a warning (and we
       don't know the -W option to disable it, let me know if you do ;-)*/
    if (0) [super dealloc];
}

@end /* __DummyGCObject */


/* The GCDoubleLinkedList is a double linked list which contains as
    the first element a dummy GCObject. This object is always the head
    of the list. A new element is introduced immediately after the
    head. This way we don't need to keep track of the head of the list
    when we remove an element. */
@interface GCDoubleLinkedList : NSObject
{
    id list;
}
- (void)addObject:(id)anObject;
- (void)removeObject:(id)anObject;
- (id)firstObject;
- (void)removeAllObjects;
@end


@implementation GCDoubleLinkedList

- init
{
    list = [__DummyGCObject new];
    return self;
}

- (void)addObject:(id)anObject
{
    id next = [list gcNextObject];

    [list gcSetNextObject:anObject];
    [anObject gcSetNextObject:next];
    [next gcSetPreviousObject:anObject];
    [anObject gcSetPreviousObject:list];
}

- (void)removeObject:(id)anObject
{
    id prev = [anObject gcPreviousObject];
    id next = [anObject gcNextObject];

    [prev gcSetNextObject:next];
    [next gcSetPreviousObject:prev];
}

- (id)firstObject
{
    return [list gcNextObject];
}

- (void)removeAllObjects
{
    [list gcSetNextObject:nil];
}

@end


@implementation GarbageCollector

#if !LIB_FOUNDATION_BOEHM_GC
static id gcObjectsToBeVisited;
#else
static NSMapTable* postingObjectsToObservers = NULL;
        /* Posting object to double linked list of observers
	   (listOfObservers).  The first element in listOfObservers is
	   a dummy element, used just to make the removing process
	   easier. */

static NSMapTable* observersToPostingObjectNodes = NULL;
        /* Observer to double linked list of nodes in listOfObservers,
	   where the observer appears. */

static void gcCollect(void)
{
    puts("GARBAGE COLLECTING ...");
}
#endif

+ (void)initialize
{
#if LIB_FOUNDATION_BOEHM_GC
    extern void (*GC_start_call_back)(void);
    GC_word mask1 = 0x7;
    GC_word mask2 = 0x3;

    GC_start_call_back = gcCollect;
    postingObjectsToObservers = NSCreateMapTableInvisibleKeysOrValues
        (NSNonOwnedPointerMapKeyCallBacks,
         NSNonOwnedPointerMapValueCallBacks,
         119, YES, NO);
    observersToPostingObjectNodes = NSCreateMapTableInvisibleKeysOrValues
        (NSNonOwnedPointerMapKeyCallBacks,
         NSNonOwnedPointerMapValueCallBacks,
         119, YES, NO);
    GC_MALLOC(4);
    nodeDescriptor1 = GC_make_descriptor (&mask1, 4);
    nodeDescriptor2 = GC_make_descriptor (&mask2, 4);
#else
    gcObjectsToBeVisited = [GCDoubleLinkedList new];
#endif
}

+ (BOOL)usesBoehmGC
{
    return _usesBoehmGC;
}

+ (void)collectGarbages
{
#if LIB_FOUNDATION_BOEHM_GC
    isGarbageCollecting = YES;
    GC_gcollect();
    isGarbageCollecting = NO;
    return;
#else
    id object;

    isGarbageCollecting = YES;

    /*  First pass. All the objects in the gcObjectsToBeVisited list
	receive the -decrementRefCount message. Each object should
	decrement the ref count of all objects contained. */
    object = [gcObjectsToBeVisited firstObject];
    while(object) {
	[object gcDecrementRefCountOfContainedObjects];
	[object gcSetVisited:NO];
	object = [object gcNextObject];
    };

    /*  Second pass. All the objects in the gcObjectsToBeVisited list
	that have the refCount greater than 0 receive the
	-incrementRefCount message.  Each object should increment the
	ref count of all objects contained.  Then it should send the
	-incrementRefCount message to all objects contained. */
    object = [gcObjectsToBeVisited firstObject];
    while(object) {
	if([object retainCount])
	    [object gcIncrementRefCountOfContainedObjects];
	object = [object gcNextObject];
    }

    /*  Third pass. All the objects that still have the refCount equal
	with 0 are part of cyclic graphs and none of the objects from
	this graph are held by some object outside graph. These
	objects receive the -dealloc message. In this method they
	should send the -dealloc message to objects that are garbage
	collectable. An object could be asked if it is garbage
	collectable by sending it the -isGarbageCollectable
	message. */
    object = [gcObjectsToBeVisited firstObject];
    while(object) {
	if([object retainCount] == 0) {
	    id nextObject = [object gcNextObject];

	    /*  Remove object from gcObjectsToBeVisited list. We have
		to keep the old nextObject because after removing the
		object from list its nextObject is altered. */
	    [gcObjectsToBeVisited removeObject:object];
	    [object dealloc];
	    object = nextObject;
	}
	else object = [object gcNextObject];
    }

    isGarbageCollecting = NO;
#endif
}

@end /* GarbageCollector */


@implementation GarbageCollector (ReferenceCountingGC)

+ (void)addObject:(id)anObject
{
#if !LIB_FOUNDATION_BOEHM_GC
    [gcObjectsToBeVisited addObject:anObject];
#endif
}

+ (void)objectWillBeDeallocated:(id)anObject
{
#if !LIB_FOUNDATION_BOEHM_GC
  {
    /*  We can remove without fear the object from its list because
	the head of the list is always the same. */
    id prev = [anObject gcPreviousObject];
    id next = [anObject gcNextObject];
    [prev gcSetNextObject:next];
    [next gcSetPreviousObject:prev];
  }
#endif
}

+ (BOOL)isGarbageCollecting		{ return isGarbageCollecting; }

@end /* GarbageCollector (ReferenceCountingGC) */



#if LIB_FOUNDATION_BOEHM_GC

typedef struct _DoubleLinkedListNode1 {
    struct _DoubleLinkedListNode1* next;
    struct _DoubleLinkedListNode1* prev;
    void* node;
    /* weak */ id postingObject;
} DoubleLinkedListNode1;

typedef struct _DoubleLinkedListNode2 {
    struct _DoubleLinkedListNode2* next;
    struct _DoubleLinkedListNode2* prev;
    /* weak */ id observer;
    /* weak */ SEL selector;
} DoubleLinkedListNode2;

/* We assume a double linked list always has a head, which is actually
   not part of the useful information maintained by the list. */

static void* newNode1 (void)
{
    void* node
        = GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _DoubleLinkedListNode1),
                                     nodeDescriptor1);
    memset (node, 0, sizeof (struct _DoubleLinkedListNode1));
    return node;
}

static void* newNode2 (void)
{
    void* node
        = GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _DoubleLinkedListNode2),
                                     nodeDescriptor2);
    memset (node, 0, sizeof (struct _DoubleLinkedListNode2));
    return node;
}

static void removeNode (void* node)
{
    DoubleLinkedListNode1* prev = ((DoubleLinkedListNode1*)node)->prev;
    DoubleLinkedListNode1* next = ((DoubleLinkedListNode1*)node)->next;

    prev->next = next;
    if (next)
        next->prev = prev;
}


@implementation GarbageCollector (BoehmGCSupport)

static void _do_finalize_object (void* object, void* client_data)
{
    /* Temporary set GC_dont_gc to YES */
    int old_GC_dont_gc = GC_dont_gc;
    DoubleLinkedListNode2* head2;
    
    GC_dont_gc = YES;
    
    fprintf(stderr,
            "_do_finalize_object %08x (%s)\n",
            (unsigned)object, ((GarbageCollector*)object)->isa->name);
    fflush(stderr);
    
    /* Inform the observers of object that it will finalize */
    head2 = NSMapGet (postingObjectsToObservers, object);
    if (head2) {
        DoubleLinkedListNode2* node = head2->next;

        while (node) {
            [node->observer performSelector:node->selector withObject:object];
            node = node->next;
        }
        NSMapRemove (postingObjectsToObservers, object);
    }
    
    [GarbageCollector unregisterObserver:object forObjectFinalization:nil];
    
    if ([(id)object respondsToSelector:@selector(gcFinalize)])
        [(id)object gcFinalize];
    
    /* Set the class of anObject to FREED_OBJECT. The further messages
       to this object will cause an error to occur. */
    ((GarbageCollector*)object)->isa = __freedObjectClass;
    
    /* Restore the value of GC_dont_gc */
    GC_dont_gc = old_GC_dont_gc;
}

+ (void)registerForFinalizationObserver:(id)observer
  selector:(SEL)selector
  object:(id)object
{
    DoubleLinkedListNode1 *head1, *node1;
    DoubleLinkedListNode2 *head2, *node2;

    [libFoundationLock lock];

    /* First insert 'object' in the postingObjectsToObservers map
       table. The value in the map table is a double linked list whose
       elements are nodes that contain the observer and the selector.
       The first element in this list is a dummy element. */
    head2 = NSMapGet (postingObjectsToObservers, object);
    if (!head2) {
        head2 = newNode2 ();
        NSMapInsert (postingObjectsToObservers, object, head2);
    }

    node2 = newNode2 ();
    node2->next = head2->next;
    if (node2->next)
        node2->next->prev = node2;
    node2->prev = head2;
    node2->observer = observer;
    node2->selector = selector;
    head2->next = node2;

    /* Now insert 'observer' in observersToPostingObjectNodes map
       table. The value in the map table is a double linked list whose
       elements are nodes that contain the posting object; the 'node'
       field of all nodes except the head are the nodes in
       listOfObservers where the observer appears. The first element of
       this list is a dummy element. */
    head1 = NSMapGet (observersToPostingObjectNodes, observer);
    if (!head1) {
        head1 = newNode1 ();
        NSMapInsert (observersToPostingObjectNodes, observer, head1);
    }

    node1 = newNode1 ();
    node1->next = head1->next;
    if (node1->next)
        node1->next->prev = node1;
    node1->prev = head1;
    node1->node = node2;
    node1->postingObject = object;
    head1->next = node1;

    /* Register finalizer for both the object and the observer. Make
       sure the object and observer are instances, class objects are
       statically allocated, they are not allocated by the collector. */
    if (CLS_ISCLASS(((GarbageCollector*)object)->isa))
        GC_REGISTER_FINALIZER(object, _do_finalize_object, NULL, NULL, NULL);
    if (CLS_ISCLASS(((GarbageCollector*)observer)->isa))
        GC_REGISTER_FINALIZER(observer, _do_finalize_object, NULL, NULL, NULL);

    [libFoundationLock unlock];
}

+ (void)unregisterObserver:(id)observer
     forObjectFinalization:(id)object
{
    DoubleLinkedListNode1* head1;

    [libFoundationLock lock];

    /* Remove the object from the list of observers in case it's
       registered as observer. */
    head1 = NSMapGet (observersToPostingObjectNodes, observer);
    if (head1) {
        DoubleLinkedListNode1* node = head1->next;

        if (!object) {	/* Remove all the occurrences of observer */
            while (node) {
                removeNode (node->node);
                node = node->next;
            }
            NSMapRemove (observersToPostingObjectNodes, observer);
        }
        else {
            while (node) {
                DoubleLinkedListNode1* next = node->next;

                if (node->postingObject == object) {
                    removeNode (node->node);
                    removeNode (node);
                    break;
                }
                node = next;
            }
            
            /* Remove the observer from the map table if there are no
               other objects to listen for. */
            if (!head1->next)
                NSMapRemove (observersToPostingObjectNodes, observer);
        }
    }
    
    [libFoundationLock unlock];
}

static int denied = 0;

+ (void)allowGarbageCollection
{
    denied--;
    if (denied <= 0) GC_dont_gc = 0;
}
+ (void)denyGarbageCollection
{
    denied++;
    if (denied > 0) GC_dont_gc = 1;
}

@end /* GarbageCollector (BoehmGCSupport) */

#endif /* LIB_FOUNDATION_BOEHM_GC */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

