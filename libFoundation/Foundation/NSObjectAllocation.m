/* 
   NSObjectAllocation.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <config.h>

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_MEMORY_H
# include <memory.h>
#endif

#if !HAVE_MEMCPY
# define memcpy(d, s, n)       bcopy((s), (d), (n))
# define memmove(d, s, n)      bcopy((s), (d), (n))
#endif

#if HAVE_STDLIB_H
# include <stdlib.h>
#else
extern void* malloc();
extern void* calloc();
extern void* realloc();
extern void free();
extern atoi();
extern atol();
#endif

#include <assert.h>

#include <Foundation/common.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/NSAutoreleasePool.h>

#include <extensions/objc-runtime.h>
#include "lfmemory.h"

#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
#  include <Foundation/NSNotification.h>
#  if LIB_FOUNDATION_LEAK_GC
#    include <Foundation/NSConcreteString.h>
#  endif
#endif

/*
* Global variables
*/

static BOOL objectRefInit = NO;

#if !LIB_FOUNDATION_BOEHM_GC
static NSMapTable* objectRefsHash = NULL;
static objc_mutex_t objectRefsMutex = NULL;
#endif

#if DEBUG
static unsigned totalMem    = 0;
FILE *logAlloc   = (void*)-1;
#endif

static BOOL objectRefIsHash = NO;
Class __freedObjectClass = nil;

/* This is a global mutex which is used to lock the global hash table that
   keeps the objects. This mutex should be locked/unlocked whenever an
   operation is performed on the global table. It should NOT be locked when
   the reference count of the object is kept right before the object.

   The thread-safe feature of libFoundation refers to the fact that it is
   guaranteed that the library is thread-safe, no matter what operations are
   performed in each thread, as long as one object does NOT receive messages
   from multiple threads that can modify its internal state*. This is also the
   case for release/retain messages that you send to an object: if you want to
   send these messages to an object from multiple threads you should use an
   external lock object to syncronize the access to it, to ensure that the ref
   count is correct. We use a lock here because the internal hash is private
   and cannot be accessed by other programs.

   As you can see having the external ref counts outside of the objects it's
   much faster than having a global hash in both single-threaded and
   multi-threaded programs.

  * Note: One notable exception are the NSLock objects which change their state
  when you send messages to them from multiple threads.
*/

static void init_refcounting(void)
{
#if DEBUG
    if (logAlloc == (void*)-1) {
        char *d;

        logAlloc = NULL;
        if ((d = getenv("NSLogAlloc"))) {
            if (strcmp(d, "YES") == 0) {
                logAlloc = fopen(".alloc", "w");
                fprintf(logAlloc, "---- pid %d ----\n", getpid());
            }
        }
        else {
            if (logAlloc)
                fprintf(stderr, "WARNING: logging object deallocation !\n");
        }
    }
#endif /* DEBUG */
    
#if LIB_FOUNDATION_BOEHM_GC || WITH_FAST_RC
    objectRefIsHash = NO;
#elif defined(OBJECT_REFCOUNT) && OBJECT_REFCOUNT == 1
    objectRefIsHash = YES;
#elif defined(OBJECT_REFCOUNT) && OBJECT_REFCOUNT == 0
    objectRefIsHash = NO;
#else 
    /* Undefined at compile-time. Use OBJECT_REFCOUNT environment variable */
    objectRefIsHash = getenv("OBJECT_REFCOUNT") ? YES : NO;
#endif

/*
  fprintf(stderr, "NSObjectAllocation: using %s refcounting\n", 
  objectRefIsHash ? "hashtable" : "extra-allocated");
*/

#if !LIB_FOUNDATION_BOEHM_GC
    if (objectRefIsHash)
	objectRefsHash
            = NSCreateMapTableWithZone(NSNonOwnedPointerMapKeyCallBacks,
                                       NSIntMapValueCallBacks, 
                                       64, nil);
    objectRefsMutex = objc_mutex_allocate();
#endif

    objectRefInit = YES;
    __freedObjectClass = objc_get_class("FREED_OBJECT");
}

#if LIB_FOUNDATION_BOEHM_GC
/* Private function used to do the finalization code on an object */
static void _do_finalize (void* object, void* client_data)
{
  [(id)object gcFinalize];

  /* Set the class of anObject to FREED_OBJECT. The further messages to this
     object will cause an error to occur. */
  ((id)object)->class_pointer = __freedObjectClass;
}
#endif

#if LIB_FOUNDATION_LEAK_GC
// track leaks

void _check_object_for_leak(void *memory, void *cd)
{
    Class        class  = Nil;
    id           object = nil;
    unsigned int rc;

    if (objectRefIsHash) {
        object = memory;
        rc     = NSExtraRefCount(object);
        class  = (Class)cd;
    }
    else {
        object = (id)&(((struct RefObjectLayout *)memory)->class_pointer);
        rc     = NSExtraRefCount(object);
        class  = (Class)cd;
    }

    if ((rc >= 1) && (rc <= 1000)) {
        fprintf(stderr, "LEAK(rc=%d): 0x%p<%s>",
                rc, object, (class ? class->name : "Nil"));

        if ([object isKindOfClass:[NSString class]]) {
            unsigned slen = [object cStringLength];
            char buf[slen + 1];
            [object getCString:buf]; buf[slen] = '\0';
            fprintf(stderr, " string=\"%s\"", buf);
        }
        
#if 0
          if ([object isKindOfClass:[NSString class]])
            fprintf(stderr, " string=\"%s\"", [object cString]);
          else
            fprintf(stderr, " description=%s", [[object description] cString]);
#endif
	  
        fprintf(stderr, "\n");
    }    
    object = nil; rc = 0; class = Nil;
}

#endif

/* 
 * Allocate an Object 
 */

NSObject *NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone)
{
    assert(CLS_ISCLASS(aClass));
    
    if (!objectRefInit)
	init_refcounting();
    
#if LIB_FOUNDATION_BOEHM_GC
    {
        size_t size = aClass->instance_size + extraBytes;
        struct objc_object *p;
        
        if (aClass->gc_object_type == NULL) {
            fprintf(stderr, "WARNING: GC object type is NULL for class %s\n",
                    aClass->name);
            fflush(stderr);

            p = GC_MALLOC(size);
        }
        else {
            if ([aClass requiresTypedMemory]) {
                p = GC_CALLOC_EXPLICTLY_TYPED(1, size,
                                              (GC_descr)(aClass->gc_object_type));
            }
            else {
                p = GC_MALLOC(size);
            }
            
            if (!p)
                objc_error(nil, OBJC_ERR_MEMORY, "Virtual memory exhausted\n");

        }
        memset (p, 0, size);
        p->class_pointer = aClass;
        /* Register the object for finalization */
        if ([(id)p respondsToSelector:@selector(gcFinalize)]) {
            GC_REGISTER_FINALIZER (p, _do_finalize, NULL, NULL, NULL);
        }
        return p;
    }
#else
    if (objectRefIsHash) {
	struct HashObjectLayout* p;
	
	p = NSZoneCalloc(zone, 1, sizeof(struct HashObjectLayout) + 
                         aClass->instance_size + extraBytes);

	p->class_pointer = aClass;
	objc_mutex_lock(objectRefsMutex);
	NSMapInsert(objectRefsHash, PTR2HSH(p), (void*)1);
	objc_mutex_unlock(objectRefsMutex);

#if LIB_FOUNDATION_LEAK_GC
        GC_REGISTER_FINALIZER_IGNORE_SELF(p, _check_object_for_leak,
                                          aClass, NULL, NULL);
#endif
#if DEBUG
        totalMem += sizeof(struct HashObjectLayout) + 
            aClass->instance_size + extraBytes;
        if (logAlloc) {
            fprintf(logAlloc,
                    "alloc-#: 0x%p<%s> size=%d (%d + %d) zone=0x%p\n",
                    p, class_get_class_name(aClass),
                    (unsigned)(sizeof(struct HashObjectLayout) + 
                      aClass->instance_size + extraBytes),
                    (unsigned)aClass->instance_size, (unsigned)extraBytes,
                    zone);
        }
#endif
	return (NSObject*)p;
    }
    else {
        struct RefObjectLayout* p;
	
        p = NSZoneCalloc(zone, 1, sizeof(struct RefObjectLayout) + 
                         aClass->instance_size + extraBytes);

        p->class_pointer = aClass;
        p->ref_count = 1;
	
#if LIB_FOUNDATION_LEAK_GC
        GC_REGISTER_FINALIZER(p, _check_object_for_leak, aClass,
                              NULL, NULL);
#endif

#if DEBUG
        totalMem += sizeof(struct RefObjectLayout) +
            aClass->instance_size + extraBytes;
        if (logAlloc) {
            unsigned size;

            size = (unsigned)(sizeof(struct RefObjectLayout) +
                              aClass->instance_size + extraBytes);
            
            fprintf(logAlloc,
                    "alloc-rc: 0x%p<%s> size=%d (%d + %d) zone=0x%p\n",
                    &(p->class_pointer),
                    aClass ? class_get_class_name(aClass) : "Nil",
                    size,
                    (unsigned)aClass->instance_size,
                    (unsigned)extraBytes,
                    zone);
        }
#endif
        return (NSObject*)(&(p->class_pointer));
    }
    
    return nil;
#endif
}

NSObject *NSCopyObject(NSObject *anObject, unsigned extraBytes, NSZone *zone)
{
    id copy = NSAllocateObject(((id)anObject)->class_pointer,
			    extraBytes, zone);
    unsigned size = ((id)anObject)->class_pointer->instance_size + 
				extraBytes;

    memcpy(copy, anObject, size);

    return copy;
}

NSZone *NSZoneFromObject(NSObject *anObject)
{
    return NSZoneFromPointer(objectRefIsHash
                             ? (void *)anObject
                             : (void *)OBJ2PTR(anObject));
}

void NSDeallocateObject(NSObject *anObject)
{
#if !LIB_FOUNDATION_BOEHM_GC
    void  *p;
    Class oldIsa;
#endif
#if DEBUG
    static int  useZombies  = -1;
    
    if (useZombies == -1) {
        char *d;

        if ((d = getenv("NSUseZombies")))
            useZombies = (strcmp(d, "YES") == 0) ? 1 : 0;
        else
            useZombies = 0;
        
        if (useZombies)
            fprintf(stderr, "WARNING: using Zombie objects !\n");
    }
#endif
    
#if LIB_FOUNDATION_BOEHM_GC
    fprintf(stderr, "WARNING: explicit free of GC object 0x%p !\n",anObject);
    abort();
    GC_FREE(anObject); anObject = nil;
    return;
#else

#if DEBUG
    if (logAlloc) {
        fprintf(logAlloc, "dealloc: 0x%p<%s>\n",
                anObject,
                class_get_class_name(((id)anObject)->class_pointer));
    }
#endif
    
    /* Set the class of anObject to FREED_OBJECT. The further messages to this
       object will cause an error to occur. */
    oldIsa = ((id)anObject)->class_pointer;
    ((id)anObject)->class_pointer = __freedObjectClass;
    
    if ((unsigned)oldIsa->instance_size >= ((sizeof(Class) * 2))) {
        /* if there is enough room for the old class pointer .. */
        ((FREED_OBJECT *)anObject)->oldIsa = oldIsa;
    }
    
    if (objectRefIsHash) {
	p = anObject;
	objc_mutex_lock(objectRefsMutex);
	NSMapRemove(objectRefsHash, PTR2HSH(anObject));
	objc_mutex_unlock(objectRefsMutex);
    }
    else {
	p = OBJ2PTR(anObject);
        ((struct RefObjectLayout *)p)->ref_count = 0;
    }

#if FIND_LEAK
    GC_REGISTER_FINALIZER_IGNORE_SELF(p, _check_object_for_leak,
                                      NULL, NULL, NULL);
#endif

#if DEBUG
    if (useZombies)
        return;
#endif
    NSZoneFree(NSZoneFromPointer(p), p);

#if 0
    fprintf(stderr, "deallocated: 0x%p\n", anObject);
#endif
    anObject = nil; p = nil;
#endif
}

/* 
 * Retain / Release NSObject 
 */

BOOL NSShouldRetainWithZone(NSObject* anObject, NSZone* requestedZone)
{
    return requestedZone == NULL
	   || requestedZone == NSDefaultMallocZone()
	   || requestedZone == [anObject zone];
}

#if LIB_FOUNDATION_BOEHM_GC

BOOL NSDecrementExtraRefCountWasZero(id anObject)
{
    return NO;
}
void NSIncrementExtraRefCount(id anObject)
{
}
unsigned NSGetExtraRefCount(id anObject)
{
    // deprecated function
    return (unsigned)-1;
}
unsigned NSExtraRefCount(id anObject)
{
    return (unsigned)-1;
}

unsigned NSAutoreleaseCountForObject(id object)
{
    return (unsigned)-1;
}

id NSFastAutorelease(id object) {
    return object;
}

#else /* !LIB_FOUNDATION_BOEHM_GC */

/* 
 * Modify the Number of References to an Object 
 */

BOOL NSDecrementExtraRefCountWasZero(id anObject)
{
    if (objectRefIsHash) {
        void* p = PTR2HSH(anObject);
        unsigned long r;
	
        objc_mutex_lock(objectRefsMutex);
        r = (unsigned long)NSMapGet(objectRefsHash, p);

        if (!r) {
            objc_mutex_unlock(objectRefsMutex);
            return YES;
        }

        NSMapInsert(objectRefsHash, p, (void*)(--r));
        objc_mutex_unlock(objectRefsMutex);
        return (r == 0);
    }
    else {
        struct RefObjectLayout* p = OBJ2PTR(anObject);
        unsigned int r = p->ref_count;
        
        if (!r)
            return YES;

        r = --(p->ref_count);
        return (r == 0);
    }
}

void NSIncrementExtraRefCount(id anObject)
{
    if (objectRefIsHash) {
	void* p = PTR2HSH(anObject);
	unsigned long r;

	objc_mutex_lock(objectRefsMutex);
	r = (unsigned long)NSMapGet(objectRefsHash, p);
	NSMapInsert(objectRefsHash, p, (void*)(r+1));
	objc_mutex_unlock(objectRefsMutex);
    }
    else {
	struct RefObjectLayout* p = OBJ2PTR(anObject);

	(p->ref_count)++;
    }
}

/* Obtain the Number of References to an Object */
unsigned NSGetExtraRefCount(id anObject)
{
    return NSExtraRefCount(anObject);
}
unsigned NSExtraRefCount(id anObject)
{
    unsigned int r;

    if (objectRefIsHash) {
	void* p = PTR2HSH(anObject);
	
	objc_mutex_lock(objectRefsMutex);
	r = (unsigned long)NSMapGet(objectRefsHash, p);
	objc_mutex_unlock(objectRefsMutex);
    }
    else {
	struct RefObjectLayout* p = OBJ2PTR(anObject);
	r = p->ref_count;
    }
    return r;
}

unsigned NSAutoreleaseCountForObject(id object)
{
    return [NSAutoreleasePool autoreleaseCountForObject:object];
}

id NSFastAutorelease(id self) {
    static Class NSAutoreleasePoolClass = Nil;
    static void (*addObject)(id,SEL,id);
    
    if (self == nil) return nil;
    
    if (NSAutoreleasePoolClass == Nil) {
        NSAutoreleasePoolClass = [NSAutoreleasePool class];
        addObject = (void*)
          [(id)NSAutoreleasePoolClass methodForSelector:@selector(addObject:)];
    }
    addObject(NSAutoreleasePoolClass, @selector(addObject:), self);
    return self;
}

#endif /* !LIB_FOUNDATION_BOEHM_GC */

@implementation FREED_OBJECT

static void _raiseSelException(FREED_OBJECT *self, SEL _selector)
{
    id exception;
    BOOL outIsa = NO;

    if (self->oldIsa) {
        if (CLS_ISCLASS(self->oldIsa))
            outIsa = YES;
    }
    
    exception = [ObjcRuntimeException alloc];
    if (outIsa) {
        exception = [exception initWithFormat:
                                 @"message '%s' sent to freed object %p (%s)", 
                                 sel_get_name(_selector), (void*)self,
                                 class_get_class_name(self->oldIsa)];
    }
    else {
        exception = [exception initWithFormat:
                                 @"message '%s' sent to freed object %p", 
                                 sel_get_name(_selector), (void*)self];
    }
    [exception raise];
}

- (id)autorelease
{
    _raiseSelException(self, _cmd);
    return nil;
}
- (oneway void)release
{
    _raiseSelException(self, _cmd);
}
- (id)retain
{
    _raiseSelException(self, _cmd);
    return nil;
}

#if GNU_RUNTIME
- (void)doesNotRecognize:(SEL)aSelector
#else
- (void)doesNotRecognizeSelector:(SEL)aSelector
#endif
{
    _raiseSelException(self, aSelector);
}

@end /* FREED_OBJECT */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
