/* GNU Objective C Runtime Thread Implementation
   Copyright (C) 1996 Free Software Foundation, Inc.

Author: Galen C. Hunt (gchunt@@cs.rochester.edu)
Modified for Mach threads by: Bill Bumgarner <bbum@@friday.com>
Condition functions added by: Mircea Oancea <mircea@@first.elcom.pub.ro>

This file is part of GNU CC.

GNU CC is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 2, or (at your option) any later version.

GNU CC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with GNU CC; see the file COPYING.  If not, write to
the Free Software Foundation, 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

/* As a special exception, if you link this library with files compiled with
   GCC to produce an executable, this does not cause the resulting executable
   to be covered by the GNU General Public License. This exception does not
   however invalidate any other reasons why the executable file might be
   covered by the GNU General Public License.  */

#include <mach/mach.h>
#include <mach/cthreads.h>
#include <objc/objc-api.h>

#if NeXT_RUNTIME
typedef void * objc_thread_t;
#endif

/********
 *  This structure represents a single mutual exclusion lock.  Lock semantics
 *  are detailed with the subsequent functions.  We use whatever lock is
 *  provided by the system.  We augment it with depth and current owner id
 *  fields to implement and re-entrant lock.
 */
struct objc_mutex 
{
    volatile objc_thread_t     owner;           /* Id of thread that owns.  */
    volatile int                depth;          /* # of acquires.           */
    struct mutex                lock;           /* cthread mutex            */
};
typedef struct objc_mutex *objc_mutex_t;

struct objc_condition 
{
    struct condition            condition;      /* cthread condition        */
};
typedef struct objc_condition *objc_condition_t;

/********
 *  Universal static variables:
 */
 
int __objc_thread_exit_status = 0;      	/* Global exit status.      */
int __objc_runtime_threads_alive = 0;		/* Number of threads alive  */
struct objc_mutex* __objc_runtime_mutex = NULL;	/* Thread create/exit mutex */

/********
 * obtain the maximum thread priority that can set for t.  Under the
 * mach threading model, it is possible for the developer to adjust the
 * maximum priority downward only-- cannot be raised without superuser
 * priviledges.  Once lowered, it cannot be raised.
 */
static int __mach_get_max_thread_priority(cthread_t t, int *base) {
    thread_t   		      threadP;
    kern_return_t             error;
    struct thread_sched_info  info;
    unsigned int              info_count=THREAD_SCHED_INFO_COUNT;
    
    if (t == NULL)
	return -1;

    threadP  = cthread_thread(t); 	/* get thread underlying */

    error=thread_info(threadP, THREAD_SCHED_INFO, 
		      (thread_info_t)&info, &info_count);

    if (error != KERN_SUCCESS)
	return -1;

    if (base != NULL)
	*base = info.base_priority;

    return info.max_priority;
}
	
/********
 *  Initialize the threads subsystem.  Returns 0 if successful, or -1 if no
 *  thread support is available.
 */
int
__objc_init_thread_system(void)
{
    return 0;                                    /* Succeeded.       */
}


int
__objc_fini_thread_system(void)
{
  return 0;
}

/********
 *  Create a new thread of execution and return its id.  Return NULL if fails.
 *  The new thread starts in "func" with the given argument.
 */
objc_thread_t
objc_thread_create(void (*func)(void *arg), void *arg)
{
    objc_thread_t       thread_id = NULL;       /* Detached thread id.      */
    cthread_t           new_thread_handle;      /* cthread handle.          */

    if (!__objc_runtime_mutex)
	__objc_runtime_mutex = objc_mutex_allocate();
    
    objc_mutex_lock(__objc_runtime_mutex);
    
    /* create thread */
    new_thread_handle = cthread_fork((cthread_fn_t)func, arg);

    if(new_thread_handle) {
      /* this is not terribly portable */
        thread_id = *(objc_thread_t *)&new_thread_handle; 
        cthread_detach(new_thread_handle);      /* fully detach thread */
        __objc_runtime_threads_alive++;         /* increment thread count */
    }
    
    objc_mutex_unlock(__objc_runtime_mutex);
    return thread_id;
}

/********
 *  Set the current thread's priority.
 */
int
objc_thread_set_priority(int priority)
{
    objc_thread_t   *t	     = objc_thread_id();
    cthread_t        cT	     = (cthread_t) t; 
    int 	     maxPriority  = __mach_get_max_thread_priority(cT, NULL);
    int              sys_priority = 0;

    if (maxPriority == -1)
	return -1;

    switch (priority) {
    case OBJC_THREAD_INTERACTIVE_PRIORITY:
        sys_priority = maxPriority;
        break;
    case OBJC_THREAD_BACKGROUND_PRIORITY:
        sys_priority = (maxPriority * 2) / 3;
        break;
    case OBJC_THREAD_LOW_PRIORITY:
        sys_priority = maxPriority / 3;
        break;
    default:
	return -1;
    }

    if (sys_priority == 0)
	return -1;
    
    if (cthread_priority(cT, sys_priority, 0) == KERN_SUCCESS)
        return 0;                               /* Changed priority. End.   */
    
    return -1;                                  /* Failed.                  */
}

/********
 *  Return the current thread's priority [well, whatever it is closest to].
 */
int
objc_thread_get_priority(void)
{
    objc_thread_t *t	        = objc_thread_id();
    cthread_t      cT	        = (cthread_t) t; /* see objc_thread_id() */
    int 	   basePriority;
    int 	   maxPriority;

    maxPriority = __mach_get_max_thread_priority(cT, &basePriority);

    if(maxPriority == -1)
	return -1;

    if (basePriority > ( (maxPriority * 2) / 3))
	return OBJC_THREAD_INTERACTIVE_PRIORITY; /* interactive priority
						 */
    if (basePriority > ( maxPriority / 3))
	return OBJC_THREAD_BACKGROUND_PRIORITY; /* background priority
						 */
    return OBJC_THREAD_LOW_PRIORITY; /* everything else is low */
}

/********
 *  Yield our process time to another thread.  Any BUSY waiting that is done
 *  by a thread should use this function to make sure that other threads can
 *  make progress even on a lazy uniprocessor system.
 */
void
objc_thread_yield(void)
{
    cthread_yield();                            /* Yield to equal thread.   */
}

/********
 *  Terminate the current tread.  Doesn't return anything.  Doesn't return.
 *  Actually, if it failed returns -1.
 */
int
objc_thread_exit(void)
{
  objc_mutex_lock(__objc_runtime_mutex);
  __objc_runtime_threads_alive--;
  objc_mutex_unlock(__objc_runtime_mutex);
      
  cthread_exit(&__objc_thread_exit_status);     /* Terminate thread.        */
  return -1;
}

/********
 *  Returns an integer value which uniquely describes a thread.  Must not be
 *  NULL which is reserved as a marker for "no thread".
 */
objc_thread_t
objc_thread_id(void)
{
  cthread_t self = cthread_self();
  return (objc_thread_t)self;
}

/********
 *  Sets the thread's local storage pointer.  Returns 0 if successful or -1
 *  if failed.
 */

int
objc_thread_set_data(void *value)
{
  cthread_set_data(cthread_self(), (any_t) value);
  return 0;
}

/********
 *  Returns the thread's local storage pointer.  Returns NULL on failure.
 */
void *
objc_thread_get_data(void)
{
  return (void *) cthread_data(cthread_self());
}

/********
 *  Allocate a mutex.  Return the mutex pointer if successful or NULL if the
 *  allocation failed for any reason.
 */
objc_mutex_t
objc_mutex_allocate(void)
{
    objc_mutex_t mutex;
    int         err = 0;
    
    if (!(mutex = (objc_mutex_t)objc_malloc(sizeof(struct objc_mutex))))
        return NULL;                            /* Abort if malloc failed.  */

    err = mutex_init(&(mutex->lock));
    
    if (err != 0) {                             /* System init failed?      */
        objc_free(mutex);                       /* Yes, free local memory.  */
        return NULL;                            /* Abort.                   */
    }
    mutex->owner = (objc_thread_t) -1;         /* No owner.                */
    mutex->depth = 0;                           /* No locks.                */
    return mutex;                               /* Return mutex handle.     */
}

/********
 *  Deallocate a mutex.  Note that this includes an implicit mutex_lock to
 *  insure that no one else is using the lock.  It is legal to deallocate
 *  a lock if we have a lock on it, but illegal to deallocate a lock held
 *  by anyone else.
 *  Returns the number of locks on the thread.  (1 for deallocate).
 */
int
objc_mutex_deallocate(objc_mutex_t mutex)
{
    int         depth;                          /* # of locks on mutex.     */

    if (!mutex)                                 /* Is argument bad?         */
        return -1;                              /* Yes, abort.              */
    depth = objc_mutex_lock(mutex);             /* Must have lock.          */
    
    mutex_unlock(&(mutex->lock));               /* Must unlock system mutex.*/
    mutex_clear(&(mutex->lock));                /* Free system mutex.       */
    
    objc_free(mutex);                           /* Free memory.             */
    return depth;                               /* Return last depth.       */
}

/********
 *  Grab a lock on a mutex.  If this thread already has a lock on this mutex
 *  then we increment the lock count.  If another thread has a lock on the 
 *  mutex we block and wait for the thread to release the lock.
 *  Returns the lock count on the mutex held by this thread.
 */
int
objc_mutex_lock(objc_mutex_t mutex)
{
    objc_thread_t thread_id;                  /* Cache our thread id.     */

    if (!mutex)                                 /* Is argument bad?         */
        return -1;                              /* Yes, abort.              */
    thread_id = objc_thread_id();               /* Get this thread's id.    */
    if (mutex->owner == thread_id)              /* Already own lock?        */
        return ++mutex->depth;                  /* Yes, increment depth.    */

    mutex_lock(&(mutex->lock));                 /* Lock cthread mutex.      */
    
    mutex->owner = thread_id;                   /* Mark thread as owner.    */
    return mutex->depth = 1;                    /* Increment depth to end.  */
}

/********
 *  Try to grab a lock on a mutex.  If this thread already has a lock on
 *  this mutex then we increment the lock count and return it.  If another
 *  thread has a lock on the mutex returns -1.
 */
int
objc_mutex_trylock(objc_mutex_t mutex)
{
    objc_thread_t         thread_id;           /* Cache our thread id.     */

    if (!mutex)                                 /* Is argument bad?         */
        return -1;                              /* Yes, abort.              */
    thread_id = objc_thread_id();               /* Get this thread's id.    */
    if (mutex->owner == thread_id)              /* Already own lock?        */
        return ++mutex->depth;                  /* Yes, increment depth.    */
    
    if (mutex_try_lock(&(mutex->lock)) == 0)    /* Lock cthread mutex.      */
        return -1;                              /* Failed, abort.           */
    
    mutex->owner = thread_id;                   /* Mark thread as owner.    */
    return mutex->depth = 1;                    /* Increment depth to end.  */
}

/********
 *  Decrements the lock count on this mutex by one.  If the lock count reaches
 *  zero, release the lock on the mutex.  Returns the lock count on the mutex.
 *  It is an error to attempt to unlock a mutex which this thread doesn't hold
 *  in which case return -1 and the mutex is unaffected.
 *  Will also return -1 if the mutex free fails.
 */
int
objc_mutex_unlock(objc_mutex_t mutex)
{
    objc_thread_t    thread_id;                /* Cache our thread id.     */
    
    if (!mutex)                                 /* Is argument bad?         */
        return -1;                              /* Yes, abort.              */
    thread_id = objc_thread_id();               /* Get this thread's id.    */
    if (mutex->owner != thread_id)              /* Does some else own lock? */
        return -1;                              /* Yes, abort.              */
    if (mutex->depth > 1)                       /* Released last lock?      */
        return --mutex->depth;                  /* No, Decrement depth, end.*/
    mutex->depth = 0;                           /* Yes, reset depth to 0.   */
    mutex->owner = (objc_thread_t) -1;         /* Set owner to "no thread".*/
    
    mutex_unlock(&(mutex->lock));               /* unlock cthread mutex.    */
    
    return 0;                                   /* No, return success.      */
}

/********
 *  Allocate a condition.  Return the condition pointer if successful or NULL
 * if the allocation failed for any reason.
 */
objc_condition_t 
objc_condition_allocate(void)
{
    objc_condition_t condition;
    
    if (!(condition = (objc_condition_t)objc_malloc(
                        sizeof(struct objc_condition))))
        return NULL;                            /* Abort if malloc failed.  */

    condition_init(&(condition->condition));
    
    return condition;                           /* Return mutex handle.     */
}

/********
 *  Deallocate a condition. Note that this includes an implicit 
 *  condition_broadcast to insure that waiting threads have the opportunity
 *  to wake.  It is legal to dealloc a condition only if no other
 *  thread is/will be using it. Here we do NOT check for other threads
 *  waiting but just wake them up.
 */
int
objc_condition_deallocate(objc_condition_t condition)
{
	condition_broadcast(&(condition->condition));
	condition_clear(&(condition->condition));
	objc_free(condition);
	return 0;
}

/********
 *  Wait on the condition unlocking the mutex until objc_condition_signal()
 *  or objc_condition_broadcast() are called for the same condition. The
 *  given mutex *must* have the depth set to 1 so that it can be unlocked
 *  here, so that someone else can lock it and signal/broadcast the condition.
 *  The mutex is used to lock access to the shared data that make up the
 *  "condition" predicate.
 */
int
objc_condition_wait(objc_condition_t condition, objc_mutex_t mutex)
{
    objc_thread_t    thread_id;                /* Cache our thread id.     */
    
    if (!mutex || !condition)                   /* Is argument bad?         */
        return -1;                              /* Yes, abort.              */

    thread_id = objc_thread_id();               /* Get this thread's id.    */
    if (mutex->owner != thread_id)              /* Does some else own lock? */
        return -1;                              /* Yes, abort.              */
    if (mutex->depth > 1)                       /* Locked more than once ?  */
        return -1;                              /* YES, return error        */
                                                /* mutex will be unlocked   */
    mutex->depth = 0;                           /* Yes, reset depth to 0.   */
    mutex->owner = (objc_thread_t) -1;         /* Set owner to "no thread".*/
    
    condition_wait(&(condition->condition),
		&(mutex->lock));                        /* unlock, wait ..., lock   */
    
    mutex->owner = thread_id;                   /* Mark thread as owner.    */
    mutex->depth = 1;                           /* Increment depth to end.  */
    return 0;                                   /* Return success.          */
}

/********
 *  Wake up all threads waiting on this condition. It is recommended that 
 *  the called would lock the same mutex as the threads in objc_condition_wait
 *  before changing the "condition predicate" and make this call and unlock it
 *  right away after this call.
 */
int
objc_condition_broadcast(objc_condition_t condition)
{
    if (!condition)
		return -1;
	condition_broadcast(&(condition->condition));
	return 0;
}

/********
 *  Wake up one thread waiting on this condition. It is recommended that 
 *  the called would lock the same mutex as the threads in objc_condition_wait
 *  before changing the "condition predicate" and make this call and unlock it
 *  right away after this call.
 */
int
objc_condition_signal(objc_condition_t condition)
{
    if (!condition)
		return -1;
	condition_signal(&(condition->condition));
	return 0;
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

