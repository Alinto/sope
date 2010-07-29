/* 
   NSConcreteUnixTask.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@net-community.com>

   Based on the code written by Aleksandr Savostyanov <sav@conextions.com>.

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
#include <extensions/objc-runtime.h>
#include <Foundation/NSUserDefaults.h>

#ifdef HAVE_LIBC_H
#  include <libc.h>
#else
#  include <unistd.h>
#endif

#if HAVE_VFORK_H
# include <vfork.h>
#endif

#include <errno.h>
#include <signal.h>

#include <sys/types.h>

#if HAVE_SYS_WAIT_H
# include <sys/wait.h>
# define WAIT_TYPE int
#else
  /* Old BSD union wait */
# define WAIT_TYPE union wait

# ifndef WEXITSTATUS
#  define WEXITSTATUS(stat_val) (int)(WIFEXITED(stat_val) \
					? (((stat_val.w_status) >> 8) & 0377) \
					: -1)
# endif
#endif

#ifndef WEXITSTATUS
# define WEXITSTATUS(stat_val) ((unsigned)(stat_val) >> 8)
#endif

#ifndef WIFEXITED
# define WIFEXITED(stat_val) (((stat_val) & 255) == 0)
#endif

#if !defined(__MINGW32__)
#  include <sys/resource.h>
#endif

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

#if HAVE_SYS_TIME_H
# include <sys/time.h>	/* for struct timeval */
#endif

#include <Foundation/common.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/UnixSignalHandler.h>
#include "NSConcreteUnixTask.h"

#include <Foundation/exceptions/GeneralExceptions.h>

static NSMapTable *unixProcessToTask = NULL;
static BOOL gotSIGCHLD = NO;

@interface NSConcreteUnixTask(Privates)
+ (void)_processExitCodes;
+ (void)_safePoint;
- (void)_safePoint;
@end

@implementation NSConcreteUnixTask

static int debugNSTask = -1;

+ (void)initialize
{
    static BOOL initialized = NO;
    
    if (!initialized) {
        UnixSignalHandler *ush;
	initialized = YES;
        
	unixProcessToTask = NSCreateMapTable (NSIntMapKeyCallBacks,
				    NSNonRetainedObjectMapValueCallBacks, 19);
        
        ush = [UnixSignalHandler sharedHandler];
        
#if !defined(__MINGW32__)
#  if defined(SIGCHLD)
	[ush addObserver:self
             selector:@selector(_childFinished:)
             forSignal:SIGCHLD
             immediatelyNotifyOnSignal:NO];
	[ush addObserver:self
             selector:@selector(_sigchldImmediate:)
             forSignal:SIGCHLD
             immediatelyNotifyOnSignal:YES];
#  elif defined(SIGCLD)
	[ush addObserver:self
             selector:@selector(_childFinished:)
             forSignal:SIGCLD
             immediatelyNotifyOnSignal:NO];
	[ush addObserver:self
             selector:@selector(_sigchldImmediate:)
             forSignal:SIGCLD
             immediatelyNotifyOnSignal:YES];
#  else
#    erro how to watch for SIGCHLD on this platform ???
#endif
#endif /* !__MINGW32__ */
    }
}

- (id)init
{
    if ((self = [super init])) {
        if (debugNSTask == -1) {
            debugNSTask = [[NSUserDefaults standardUserDefaults]
                                           boolForKey:@"NSDebugTask"] ? 1 : 0;
        }
    }
    return self;
}

- (void)dealloc
{
    if (self->pid && self->isRunning) {
	NSMapRemove (unixProcessToTask, (void*)(long)pid);
    }
    
    RELEASE(self->taskPath);
    RELEASE(self->currentDirectory);
    RELEASE(self->taskArguments);
    RELEASE(self->taskEnvironment);
    RELEASE(self->standardInput);
    RELEASE(self->standardOutput);
    RELEASE(self->standardError);
    [super dealloc];
}

- (void)setLaunchPath:(NSString*)path
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(self->taskPath, path);
}

- (void)setArguments:(NSArray*)arguments
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(taskArguments, arguments);
}

- (void)setEnvironment:(NSDictionary*)dict
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(self->taskEnvironment, dict);
}

- (void)setCurrentDirectoryPath:(NSString*)path
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(currentDirectory, path);
}

- (void)setStandardInput:(id)input
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(self->standardInput, input);
}
- (id)standardInput
{
    return self->standardInput;
}

- (void)setStandardOutput:(id)output
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(self->standardOutput, output);
}
- (id)standardOutput
{
    return self->standardOutput;
}

- (void)setStandardError:(id)error
{
    if (self->isRunning || self->childHasFinished) {
        [NSException raise:NSInvalidArgumentException
                     format:@"task is already launched."];
    }
    ASSIGN(self->standardError, error);
}
- (id)standardError
{
    return self->standardError;
}

- (NSString *)launchPath
{
    return self->taskPath;
}
- (NSArray *)arguments
{
    return self->taskArguments;
}
- (NSDictionary *)environment
{
    return self->taskEnvironment;
}
- (NSString *)currentDirectoryPath
{
    return self->currentDirectory;
}

- (BOOL)isRunning
{
    return self->isRunning;
}
- (unsigned int)processId
{
    return self->pid;
}

- (void)_execChild
{
    int          i, count, fd;
    char         *path, **parg;
    NSEnumerator *enumerator;

    if (self->standardInput) {
        int fd;
        
	close(0);

        fd = [self->standardInput isKindOfClass:[NSPipe class]]
            ? [[self->standardInput fileHandleForReading] fileDescriptor]
            : [self->standardInput fileDescriptor];
        dup2(fd, 0);
    }
    if (self->standardOutput) {
	close(1);
        fd = [self->standardOutput isKindOfClass:[NSPipe class]]
            ? [[self->standardOutput fileHandleForWriting] fileDescriptor]
            : [self->standardOutput fileDescriptor];
        dup2(fd, 1);
    }
    if (self->standardError) {
	close(2);
        fd = [self->standardError isKindOfClass:[NSPipe class]]
            ? [[self->standardError fileHandleForWriting] fileDescriptor]
            : [self->standardError fileDescriptor];
        dup2(fd, 2);
    }

    // close all descriptors but stdin, stdout and stderr (0,1 and 2)
    // (this close procedure includes the pipe descriptors !)
#if !defined(__MINGW32__)
    for (fd = 3; fd < NOFILE; fd++)
	close(fd);
#endif

    if (self->currentDirectory)
	chdir([self->currentDirectory cString]);

    count   = [taskArguments count];
    parg    = (char**)Malloc ((count + 2) * sizeof(void*));
    parg[0] = Strdup ([self->taskPath cString]);
    for (i = 0; i < count; i++)
	parg[i + 1] = Strdup ([[taskArguments objectAtIndex:i] cString]);
    parg[count + 1] = NULL;
    
    path = Strdup ([self->taskPath cString]);
    
    if (taskEnvironment) {
        char **penv;
        
        count = [taskEnvironment count];
        penv = (char**)Malloc ((count + 1) * sizeof(void*));
        enumerator = [taskEnvironment keyEnumerator];
        for (i = 0; i < count; i++) {
            NSString* key = [enumerator nextObject];
            const char* keyCString = [key cString];
            const char* valueCString = [[taskEnvironment objectForKey:key]
                                                         cString];
            char buffer[Strlen(keyCString) + Strlen(valueCString) + 2];

            sprintf (buffer, "%s=%s", keyCString, valueCString);
            penv[i] = Strdup (buffer);
        }
        penv[count] = NULL;
        
        if (execve (path, parg, penv) == -1) {
            NSLog(@"Can't launch the child process, exec() failed!",
                  strerror (errno));
        }
        lfFree(penv);
    }
    else {
        if (execvp (path, parg) == -1) {
            NSLog(@"Can't launch the child process, exec() failed!: %s",
                  strerror (errno));
        }
    }
    lfFree(parg);
}

#if !defined(__MINGW32__)

+ (void)_safePoint {
    if (gotSIGCHLD) [self _processExitCodes];
}
- (void)_safePoint {
    [[self class] _safePoint];
}

+ (void)_processExitCodes {
    /* Note: this may not allocate memory if
       +doesNotifyNotificationObserversInSignalHandler
       returns YES.
       (it shouldn't)
    */
    WAIT_TYPE          s;
    pid_t              unixPid;
    NSConcreteUnixTask *task;
    UnixSignalHandler  *ush;
    NSMapEnumerator    e;
    extern BOOL UnixSignalHandlerIsProcessing;
    
    if (UnixSignalHandlerIsProcessing) {
        /* not really allowed to call print in a sig handler ... */
        fprintf(stderr,"%s: called in sig handler context ...\n",
                __PRETTY_FUNCTION__);
        fflush(stderr);
        return;
    }
    
    ush = [UnixSignalHandler sharedHandler];
    [ush blockSignal:SIGCHLD];
    gotSIGCHLD = NO; /* reset signal handler flag */
    
#if 1
    /* process all SIGCHLD signals */
    if (unixProcessToTask) {
        NSMutableArray *toBeNotified = nil;
        int left = 0, terminated = 0;
        
        e = NSEnumerateMapTable(unixProcessToTask); // THREAD ?
        
        while (NSNextMapEnumeratorPair(&e,(void*)&unixPid,(void*)&task)) {
            pid_t res;
            
            if (!task->isRunning) continue;
            
            res = waitpid(unixPid, &s, WNOHANG);
            
            if (res == unixPid) {
                if (WIFEXITED(s))
                    task->status = WEXITSTATUS(s);
                else {
                    /* task abnormally returned */
                    task->status = -1;
                }
                
                /* mark task object as terminated */
                task->isRunning        = NO;
                task->childHasFinished = YES;
                
                /* later post a notification ... */
                if (toBeNotified == nil)
                    toBeNotified = [NSMutableArray arrayWithCapacity:16];
                [toBeNotified addObject:task];
                
                terminated++;
            }
            else if (res == 0) {
                /* task is still running :-) */
                left++;
            }
            else if (res == -1) {
                /* error */
                if (errno != ECHILD /* child isn't up yet ;-) */) {
                    fprintf(stderr,
                            "ERROR(%s): waitpid(%u): %i %s\n",
                            __PRETTY_FUNCTION__,
                            unixPid, errno, strerror(errno));
                    fflush(stderr);
                }
            }
            else {
                /* different pid ??? */
                fprintf(stderr,
                        "ERROR(%s): waitpid(%u) returned a different pid %u\n",
                        __PRETTY_FUNCTION__,
                        unixPid, res);
                fflush(stderr);
            }
        }
        
        if (terminated > 1 || debugNSTask) {
            fprintf(stderr,
                    "%s: %i task%s running, %i task%s terminated\n",
                    __PRETTY_FUNCTION__,
                    left,       (left==1?"":"s"),
                    terminated, (terminated==1?"":"s"));
        }
        
        /* post notifications */
        if (toBeNotified) {
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            NSEnumerator *e;
            
            e = [toBeNotified objectEnumerator];
            while ((task = [e nextObject])) {
                /* should we delay posting to the runloop queue ASAP ? */
                
                if (task->pid) {
                    NSMapRemove(unixProcessToTask, (void*)(long)task->pid);
                    task->pid = 0;
                }
                
                [nc postNotificationName:NSTaskDidTerminateNotification
                    object:task];
            }
        }
    }
    else {
        NSLog(@"ERROR(%s): missing unixProcessToTask ...",
              __PRETTY_FUNCTION__);
    }
#else
    /* process a single SIGCHLD signal */
    unixPid = wait(&s);
    
    if ((long)unixPid != -1) {
        /* lookup the task object of the terminated child */
        if ((task = NSMapGet(unixProcessToTask, (void*)(long)unixPid)) == nil)
            return;
        
        /* if task terminated via _exit(), retrieve and set the exit status */
        if (WIFEXITED(s))
            task->status = WEXITSTATUS(s);
    
        /* mark task object as terminated */
        task->isRunning        = NO;
        task->childHasFinished = YES;
    
        /* post notification that task did terminate (new in MacOSX-S) */
        [[NSNotificationCenter defaultCenter]
                               postNotificationName:
                               NSTaskDidTerminateNotification
                               object:task];
    }
#endif
    [ush enableSignal:SIGCHLD];
}

+ (void)_sigchldImmediate:(int)signum
{
    /*
      Do NOT do anything in this immediate signal handler !!!,
      just set flags etc ...
    */
#if DEBUG && 0
    /* this is disallowed in sighandlers !!! only for debugging */
    if (!gotSIGCHLD)
        printf("SIGCHLD ...\n");
    else
        printf("SIGCHLD (was set) ...\n");
#endif
    gotSIGCHLD = YES;
}
+ (void)_childFinished:(int)signum
{
    /* 
       Florian:
       We don't use self here because it sometimes isn't actually "self" (It's
       NSFrameInvocation)
       Seems like there are problems with the UnixSignalHandler code
       
       HH:
       I have no idea how this can ever happen. My guess is that your GCC
       break-optimizes the code since I _never_ had this issue.
       
       Note that signal handlers run with a different stack.
    */
#if 1
    [NSConcreteUnixTask _processExitCodes];
#else
    [self _processExitCodes];
#endif
}

#endif /* !defined(__MINGW32__) */

- (void)launch
{
    if (self->taskPath == nil) {
	[[[InvalidArgumentException alloc]
		  initWithReason:@"the task's executable name is not setup!"] raise];
    }

    if (![[NSFileManager defaultManager]
                         isExecutableFileAtPath:self->taskPath]){
	[[[InvalidArgumentException alloc]
		  initWithReason:@"the task's path is not executable!"] raise];
    }
    
    if (isRunning)
	return;
    
    status = 0;

#if defined(SIGCHLD)
    [[UnixSignalHandler sharedHandler] blockSignal:SIGCHLD];
#elif defined(SIGCLD)
    [[UnixSignalHandler sharedHandler] blockSignal:SIGCLD];
#endif

#if defined(__MINGW32__)
#  warning NSTask not supported yet with mingw32
#else

#ifdef linux
    self->pid = fork();
#else
    self->pid = vfork();
#endif
    
    switch (self->pid) {
	case -1:	/* error */
	    NSLog(@"Can't launch the child process, vfork() failed: %s!",
		  strerror (errno));
	    break;

	case 0:
#if defined(SIGCHLD)
	    [[UnixSignalHandler sharedHandler] enableSignal:SIGCHLD];
#elif defined(SIGCLD)
	    [[UnixSignalHandler sharedHandler] enableSignal:SIGCLD];
#endif
	    [self _execChild];
	    break;
            
	default:
	    isRunning = YES;
	    NSMapInsert (unixProcessToTask, (void*)(long)pid, self);
#if defined(SIGCHLD)
	    [[UnixSignalHandler sharedHandler] enableSignal:SIGCHLD];
#elif defined(SIGCLD)
	    [[UnixSignalHandler sharedHandler] enableSignal:SIGCLD];
#endif
            // close handles of pipes
            if ([self->standardInput isKindOfClass:[NSPipe class]])
                [[self->standardInput fileHandleForReading] closeFile];
            else
                [self->standardInput closeFile];
            
            if ([self->standardOutput isKindOfClass:[NSPipe class]])
                [[self->standardOutput fileHandleForWriting] closeFile];
            else
                [self->standardOutput closeFile];
                
            if ([self->standardError isKindOfClass:[NSPipe class]])
                [[self->standardError fileHandleForWriting] closeFile];
            else
                [self->standardError closeFile];

	    break;
    }
    
    [self _safePoint];
#endif /* !MINGW32 */
}

- (void)terminate
{
    [self _safePoint];
    
    if (self->childHasFinished) {
	/* -terminate has been already sent and the child finished */
	return;
    }

#if 0 // HH: this is wrong, the task could have terminated itself before ...
    if (!self->isRunning) {
	[([[InvalidArgumentException alloc]
		    initWithReason:@"task has not been launched yet!"] raise];
    }
#endif

#if !defined(__MINGW32__)
    /* send SIGTERM to process */
    if (self->pid)
	kill(self->pid, SIGTERM);

    [self _safePoint];
#if 0
    /*
      Ovidiu wrote:
       Post the termination notification. A better idea would be to post this
       notification after the child has exited, by adding the task object
       as an observer to UnixSignalHandler in the signal handler function.
       But we keep here the same semantics with that in documentation.

      Helge says: ;-)
       That's now the case in MacOSX-S. The notification is posted when the
       child did exit.
    */
    [[NSNotificationCenter defaultCenter]
	postNotification:
	    [NSNotification notificationWithName:NSTaskDidTerminateNotification
			    object:self]];
#endif
#endif /* !MINGW32 */
}

- (void)interrupt
{
    [self _safePoint];
    if (self->childHasFinished) {
	/* -terminate has been already sent and the child finished */
	return;
    }

    if (!self->isRunning) {
	[[[InvalidArgumentException alloc]
		    initWithReason:@"task has not been launched yet!"] raise];
    }

#if !defined(__MINGW32__)
    /* send interrupt signal to process */
    if (pid)
	kill(pid, SIGINT);
    [self _safePoint];
#endif
}

- (int)terminationStatus
{
    [self _safePoint];
    if (self->isRunning) {
	[[[InvalidArgumentException alloc]
		  initWithReason:@"task is still running!"] raise];
    }
    return status;
}

- (void)waitUntilExit
{
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    
    [self _safePoint];
    
    while (self->isRunning) {
	NSDate *aDate;
	CREATE_AUTORELEASE_POOL(pool);
        {
            [self _safePoint];
            aDate = [runLoop limitDateForMode:NSDefaultRunLoopMode];
            [self _safePoint];
            [runLoop acceptInputForMode:NSDefaultRunLoopMode beforeDate:aDate];
            [self _safePoint];
        }
	RELEASE(pool);
    }
}

/* description */

- (NSString *)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[512];

    sprintf(buffer,
            "<0x%p<%s> isRunning=%s childHasFinished=%s pid=%d>",
            self, (char*)object_get_class_name(self),
            self->isRunning ? "YES" : "NO",
            self->childHasFinished ? "YES" : "NO",
            (unsigned)self->pid);
    return [NSString stringWithCString:buffer];
}

@end /* NSConcreteUnixTask */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
