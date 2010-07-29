/* 
   NSException.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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

#ifdef HAVE_LIBC_H
# include <libc.h>
#else /* GNU CC comes with unistd.h */
# include <unistd.h>
#endif

#if HAVE_STRING_H
# include <string.h>
#endif
#if HAVE_MEMORY_H
# include <memory.h>
#endif

#if HAVE_STDLIB_H
#include <stdlib.h>
#else
extern char* getenv(char*);
#endif

#include <stdio.h>
#include <signal.h>

#include <Foundation/common.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSData.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include "PrivateThreadData.h"

#define HAVE_GDB 0
#if !defined(__WIN32__) && HAVE_GDB && DEBUG
#  define WITH_GDB_BACKTRACE 1
#endif

void _default_exception_handler(NSException* exception)
{
    fprintf(stderr, "Uncatched Objective-C exception:\n");
    fprintf(stderr, "%s\n", [[exception errorString] cString]);

    [NSException printBacktrace];
    
    if(getenv("CRASH_WITH_ABORT"))
	abort();
    else
        exit(1);
}

#ifdef BROKEN_COMPILER
static NSUncaughtExceptionHandler* uncaughtHandler = _default_exception_handler;
#endif

static NSHandler firstExceptionHandler;
static NSHandler *lastHandler    = NULL;
static BOOL      isMultiThreaded = NO;

void _init_first_exception_handler(NSHandler *handler)
{
    static BOOL initialized = NO;
    if (!initialized) {
            handler->previousHandler = NULL;
            memset(&(handler->jmpState), 0, sizeof(jmp_buf));
#ifndef BROKEN_COMPILER
            handler->handler = (THandlerFunction)_default_exception_handler;
#endif
    }
}

void _NSAddHandler(NSHandler *exHandler)
{
    if (!isMultiThreaded) {
        if(!lastHandler) {
            /* We were called for the first time. */
            [NSException initialize];
        }
        exHandler->previousHandler = lastHandler;
        lastHandler = exHandler;
    } else {
        NSHandler *aHandler;
	PrivateThreadData* threadData = [[NSThread currentThread]
						_privateThreadData];

        aHandler = [threadData threadDefaultExceptionHandler];
        exHandler->previousHandler = aHandler;
        [threadData setThreadDefaultExceptionHandler:exHandler];
    }
}

void _NSRemoveHandler(NSHandler *handler)
{
    if (!isMultiThreaded) {
        lastHandler = lastHandler->previousHandler;
    } else {
	PrivateThreadData* threadData = [[NSThread currentThread]
						_privateThreadData];
        NSHandler *aHandler;

        aHandler = [threadData threadDefaultExceptionHandler];
	[threadData
		setThreadDefaultExceptionHandler:aHandler->previousHandler];
    }
}

@implementation NSException

+ (void)initialize
{
    static BOOL initialized = NO;

    if(!initialized) {
	initialized = YES;
	[NSAssertionHandler initialize];
        _init_first_exception_handler(&firstExceptionHandler);
        lastHandler = &firstExceptionHandler;
    }
}

+ (void)taskNowMultiThreaded:notification
{
    [[[NSThread currentThread] _privateThreadData]
	    setThreadDefaultExceptionHandler:lastHandler];
    lastHandler = NULL;
    isMultiThreaded = YES;
}

+ (NSException *)exceptionWithName:(NSString *)_name
  reason:(NSString *)_reason
  userInfo:(NSDictionary *)_userInfo
{
    return [[[self alloc]
                   initWithName:_name reason:_reason userInfo:_userInfo]
                   autorelease];
}

+ (void)raise:(NSString *)_name
  format:(NSString *)_format,...
{
    va_list ap;
    
    va_start(ap, _format);
    [self raise:_name format:_format arguments:ap];
    va_end(ap);
}

+ (void)raise:(NSString *)_name
  format:(NSString *)_format
  arguments:(va_list)argList
{
  NSException *exception = [self exceptionWithName:_name
                                 reason:Avsprintf(_format, argList)
                                 userInfo:nil];
  [exception raise];
}

- (id)initWithName:(NSString*)_name
  reason:(NSString*)_reason
  userInfo:(NSDictionary*)_userInfo
{
    self->name     = [_name   copy];
    self->reason   = [_reason copy];
    self->userInfo = RETAIN(_userInfo);
    
    return self;
}

- (void)raise
{
    NSHandler         *ex;
    PrivateThreadData *threadData = nil;
    
    if (!isMultiThreaded)
        ex = lastHandler;
    else {
        threadData = [[NSThread currentThread] _privateThreadData];
        ex = [threadData threadDefaultExceptionHandler];
    }
    
    if (ex == NULL) {
	fprintf (stderr, "Uncaught exception %s\n",
		 [[self errorString] cString]);
	abort();
    }

    self = RETAIN(self); // handler needs to release localException !
    
#ifdef BROKEN_COMPILER
    if (ex->previousHandler == NULL) {
        if (!isMultiThreaded)
            uncaughtHandler(self);
        else
            [threadData invokeUncaughtExceptionHandlerWithException:self];
    }
    else {
	ex->exception = self;
	longjmp(ex->jmpState, 1);
    }
#else
    (ex->handler)(self);
#endif
}

- (void)dealloc
{
    RELEASE(self->name);
    RELEASE(self->reason);
    RELEASE(self->userInfo);
    [super dealloc];
}

- (NSString *)name
{
    return self->name ? self->name : NSStringFromClass(isa);
}

- (NSString *)reason
{
    return self->reason;
}
- (NSDictionary *)userInfo
{
    return self->userInfo;
}

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    return [NSString stringWithFormat:
		       @"(Exception name:%@ class:%@ reason:%@ info:%@)",
		     name ? name : (NSString *)@"<nil>",
		     NSStringFromClass(isa),
		     reason ? reason : (NSString *)@"<nil>",
		     userInfo
		     ? [userInfo descriptionWithLocale:locale]
		     : (NSString *)@"<nil>"];
}

- (NSString *)description
{
    return [self descriptionWithLocale:nil];
}

@end /* NSException */


@implementation NSException (Extensions)

- (BOOL)exceptionIsKindOfClass:(Class)class
{
    return [self isKindOfClass:class];
}

- (BOOL)exceptionIsIn:(NSArray*)exceptions
{
    int i, n = [exceptions count];

    for(i = 0; i < n; i++)
	if([self exceptionIsKindOfClass:[[exceptions objectAtIndex:i] class]])
	    return YES;
    return NO;
}

- (NSString *)errorString
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[1024];
    
    sprintf(buffer, "exceptionClass %s\nReason: %s\nUserInfo: %s\n",
            [[[self class] description] cString],
            ([self reason] ? [[self reason] cString] : "null reason"),
            ([self userInfo]
             ? [[[self userInfo] description] cString]
             : "no userinfo"));
    return [NSString stringWithCString:buffer];
}

- (id)initWithFormat:(NSString *)format, ...
{
    va_list ap;

    va_start(ap, format);
    self->reason = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return self;
}

- (id)initWithFormat:(NSString *)format arguments:(va_list)ap
{
    self->reason = [[NSString alloc] initWithFormat:format arguments:ap];
    return self;
}

- (id)setName:(NSString *)_name
{
    ASSIGN(self->name, _name);
    return self;
}

- (id)setReason:(NSString *)_reason
{
    ASSIGN(self->reason, _reason);
    return self;
}

- (id)setUserInfo:(NSDictionary *)_userInfo
{
    ASSIGN(self->userInfo, _userInfo);
    return self;
}

@end /* NSException (Extensions) */


LF_DECLARE NSString *NSInconsistentArchiveException = @"Archive is inconsistent";
LF_DECLARE NSString *NSGenericException            = @"Generic exception";
LF_DECLARE NSString *NSInternalInconsistencyException = @"Internal inconsistency";
LF_DECLARE NSString *NSInvalidArgumentException    = @"Invalid argument";
LF_DECLARE NSString *NSMallocException             = @"Memory exhausted";
LF_DECLARE NSString *NSObjectInaccessibleException = @"Object inaccessible";
LF_DECLARE NSString *NSObjectNotAvailableException = @"Object not available";
LF_DECLARE NSString *NSDestinationInvalidException = @"Destination invalid";
LF_DECLARE NSString *NSPortTimeoutException        = @"Port timeout";
LF_DECLARE NSString *NSInvalidSendPortException    = @"Invalid send port";
LF_DECLARE NSString *NSInvalidReceivePortException = @"Invalid receive port";
LF_DECLARE NSString *NSPortSendException           = @"Port send failed";
LF_DECLARE NSString *NSPortReceiveException        = @"Port receive failed";
LF_DECLARE NSString *NSOldStyleException           = @"Old style exception";
LF_DECLARE NSString *NSRangeException              = @"Range exception";


NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void)
{
    [NSException initialize];

    if (!isMultiThreaded) {
#ifdef BROKEN_COMPILER
        return uncaughtHandler;
#else
        return (NSUncaughtExceptionHandler *)firstExceptionHandler.handler;
#endif
    }
    else {
        return [[[NSThread currentThread] _privateThreadData]
                           uncaughtExceptionHandler];
    }
}

void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *handler)
{
    [NSException initialize];

    if (!isMultiThreaded) {
#ifdef BROKEN_COMPILER
        uncaughtHandler = handler;
#else
        firstExceptionHandler.handler = (THandlerFunction)handler;
#endif
    }
    else
        [[[NSThread currentThread] _privateThreadData]
            setUncaughtExceptionHandler:handler];
}


/*
* Assertions.
*/

@implementation NSAssertionHandler

static id currentHandler = nil;

+ (void)initialize
{
    static BOOL initialized = NO;

    if(!initialized) {
	initialized = YES;
	currentHandler = [[self alloc] init];
	[NSException initialize];
    }
}

+ (NSAssertionHandler*)currentHandler
{
    return currentHandler;
}

- (void)handleFailureInFunction:(NSString*)functionName
    file:(NSString*)fileName
    lineNumber:(int)line
    description:(NSString*)format,...
{
    va_list ap;

    va_start(ap, format);
    NSLog(@"Assertion failed in file %@, line %d, function %@:",
			    fileName, line, functionName);
    NSLogv(format, ap);
    [[[AssertException alloc] initWithFormat:format arguments:ap] raise];
    va_end(ap);
}

- (void)handleFailureInMethod:(SEL)selector
    object:(id)object
    file:(NSString*)fileName
    lineNumber:(int)line
    description:(NSString*)format,...
{
    va_list ap;

    va_start(ap, format);
    NSLog(@"Assertion failed in file %@, line %d, method %@:",
	    fileName, line, NSStringFromSelector(selector));
    NSLogv(format, ap);
    [[[AssertException alloc] initWithFormat:format arguments:ap] raise];
    va_end(ap);
}

@end /* NSAssertionHandler */


/* backtracing stuff */

#if WITH_GDB_BACKTRACE

#if HAVE_SYS_TIME_H
# include <sys/time.h>	/* for struct timeval */
#endif
#if HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#include <sys/types.h>
#include <sys/wait.h>

@implementation NSException(Backtrace)

/* print program backtrace using gdb */

extern volatile BOOL _libFoundation_backtraceFinished;
volatile BOOL _libFoundation_backtraceFinished = YES;

extern char *_libFoundation_argv0;

static BOOL  _st_done = NO; /* signals whether gdb did exit  */
static pid_t pid      = 0;  /* pid of program being debugged */
static char  btPath[512] = { '\0' }; /* path to backtrace-file        */

static void gdbSigChild(int signum)
{
    /* invoked if gdb exits */
    _st_done = YES;
}
static void backtraceProcess(void)
{
    char *gdbCommands[] = {
        "backtrace\n",
        "p _libFoundation_backtraceFinished = 0\n",
        "detach\n",
        "quit\n",
        NULL
    };
    int    inPipe[2], outPipe[2];
    pid_t  gdbPid;
    
    /* hook in gdb-exit handler */
    signal(SIGCHLD, gdbSigChild);

    if (pipe(inPipe) != 0) {
        /* pipe setup failed */
        goto failedExit;
    }
    if (pipe(outPipe) != 0) {
        /* pipe setup failed */
        goto failedExit;
    }
    
    if ((gdbPid = fork()) > 0) {
        /* gdb handler (IO) process */
        fd_set fdset;
        int    i;
        BOOL   foundHash, lastNewline;
        int    logfd;
        
        /* send commands to gdb */
        for (i = 0; gdbCommands[i]; i++)
            write(inPipe[1], gdbCommands[i], strlen(gdbCommands[i]));
        
        /* init vars */
        FD_ZERO(&fdset);
        FD_SET(outPipe[0], &fdset);
        foundHash   = NO;
        lastNewline = NO;

        logfd = 1;
        if (btPath[0] != '\0') {
            /* log to file */
            logfd = open(btPath, O_WRONLY | O_CREAT | O_TRUNC, 0666);
            if (logfd < 0)
                /* open failed, log to stdout .. */
                logfd = 1;
        }
        
        /* IO loop (while gdb did not exit) */
        while (!_st_done) {
            fd_set         readset;
            struct timeval tv;
            int            numSelected;
            
            readset = fdset;
            tv.tv_sec  = 1; /* one second timeout */
            tv.tv_usec = 0;
            
            numSelected = select(FD_SETSIZE, &readset, NULL, NULL, &tv);
            if (numSelected == -1)
                /* select failed */
                break;

            if (numSelected > 0) {
                char c;
                
                if (!(FD_ISSET(outPipe[0], &readset)))
                    continue;

                /* read a byte */
                if (!read(outPipe[0], &c, 1))
                    continue;

                //fputc(c, stdout);
                
                if (!foundHash) {
                    if (c == '#') {
                        foundHash = YES;
                        write(logfd, &c, 1);
                    }
                    else if (lastNewline) {
                        /* a 'hashline' followed by a newline */
                        lastNewline = NO;
                        if (c != '(')
                            /* continuation line */
                            foundHash = YES;
                    }
                }
                else {
                    write(logfd, &c, 1);
                    
                    if ((c == '\n') || (c == '\r')) {
                        foundHash = NO;
                        lastNewline = YES;
                    }
                }
            }
        }
        if (logfd > 2)
            close(logfd);
    }
    else if (gdbPid == 0) {
        /* gdb itself */
        char *argv[4];
        char ppid[8];
        
        sprintf(ppid, "%d", pid);
        argv[0] = "gdb";
        argv[1] = _libFoundation_argv0; /* path to program being debugged */
        argv[2] = &(ppid[0]);
        argv[3] = NULL;
        
        /* map stdio to pipe handled by handler process */
        close(0); close(1); close(2);
        dup2(inPipe[0],  0);
        dup2(outPipe[1], 1);
        dup2(outPipe[1], 2);
        
        /* load & run gdb */
        execvp(argv[0], &(argv[0]));

        /* if we get here, an error occured */
        goto failedExit;
    }
    else {
        /* gdb fork failed */
        goto failedExit;
    }

    return;
 failedExit:
    perror("sth failed ..");
    kill(pid, 9);
    _exit(0);
}

static BOOL storeBacktrace = YES;

+ (NSString *)backtrace
{
    pid_t backtracePid;
    pid = getpid(); /* store pid of program being debugged */
    if (storeBacktrace)
        sprintf(btPath, "/tmp/backtrace.pid_%d", pid);
    else
        btPath[0] = '\0';
    
    /* fork backtrace process */

    if ((backtracePid = fork()) > 0) {
        /* process being debugged .. */
        int btStatus;
        
        /* loop until gdb flags exit (by setting that global) */
        while (_libFoundation_backtraceFinished)
            ;
        _libFoundation_backtraceFinished = YES;
        
        /* wait for IO handler */
        waitpid(backtracePid, &btStatus, 0);
        
        /* load backtrace file */
        if (storeBacktrace) {
            NSData   *data;
            NSString *p;
            
            p = [[NSString alloc] initWithCString:btPath];
            data = [[NSString alloc] initWithContentsOfFile:p];
            RELEASE(p);
            return AUTORELEASE(data);
        }
    }
    else if (backtracePid == 0) {
        /* run backtrace process */
        backtraceProcess();
        /* should never return */
        exit(0);
    }
    else {
        /* could not fork gdb */
    }
    pid = 0;
    return nil;
}
+ (void)printBacktrace
{
    BOOL oldVal = storeBacktrace;
    storeBacktrace = NO;
    [self backtrace];
    storeBacktrace = oldVal;
}

@end /* NSException(Backtrace) */

#else

@implementation NSException(Backtrace)

+ (NSString *)backtrace
{
    return nil;
}
+ (void)printBacktrace
{
}

@end

#endif

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
