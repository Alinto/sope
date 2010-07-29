/* 
   NSProcessInfo.m

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

#include <config.h>

#include <stdio.h>

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#if HAVE_PROCESS_H
# include <process.h>
#endif

#if HAVE_WINDOWS_H
# include <windows.h>
#endif

#if HAVE_NETINET_IN_H
# include <netinet/in.h>
#endif

#if defined(__CYGWIN32__) && 0
# include <cygwin32/in.h>
#endif

#if defined(__MINGW32__)
# include <winsock.h> // gethostbyname
#endif

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/StackZone.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>

#include <extensions/objc-runtime.h>

/*
 * Static global vars
 */

static NSString* operatingSystem = @TARGET_PLATFORM;

// The shared NSProcessInfo instance
static NSProcessInfo* processInfo = nil;

// Host name of machine executing the process
static NSString* hostName = nil;   

// Current process name
static NSString* processName = nil;

// Array of NSStrings (argv[0] .. argv[argc-1])
static NSArray* arguments = nil;

// Dictionary of environment vars and their values
static NSDictionary* environment = nil;

// Use a special zone to keep the environment variables to make possible
// debugging when we use the DejaGnu tests. This zone is allocated big enough
// to keep all the needed objects.
static NSZone* environmentZone = nil;

/*
 * NSProcessInfo implementation
 */

char *_libFoundation_argv0 = NULL;

@implementation NSProcessInfo

+ (void)initializeWithArguments:(char**)argv
    count:(int)argc
    environment:(char**)env
{
    if (processInfo)
	return;

    if (argv) {
        int i, count;
        char str[1024];
        
        /* Create an autorelease pool since there might be no one in effect
           at this moment. */
        CREATE_AUTORELEASE_POOL(pool);

        _libFoundation_argv0 = argv[0];
        
        /*
          Allocate in front to avoid recursion
        */
        processInfo = [[self allocWithZone:environmentZone] init];

        /* Create a zone big enough to hold all the environment variables. This
           should be done to make the program behaves exactly the same when it
           is run from DejaGnu, gdb or command line. */
#if 1
        environmentZone = NSDefaultMallocZone();
#else
        environmentZone = [[StackZone alloc]
                                      initForSize:128000
                                      granularity:0 canFree:NO];
#endif

        /* Getting the process name */
#if defined(__MINGW32__)
        {
            /*
              Mingw32 sometimes has both '\' and '/' as path separators,
              this is because some native Windows shells (eg tcsh or bash)
              can handle both.
            */
            unsigned char *ppath, *tmp;
            int           len, pos;
	    
	    ppath = argv[0];
	    len   = strlen(ppath);
            tmp   = &(ppath[len - 1]);
	    
            for (pos = 0; pos < len; pos++) {
                if ((*tmp == '/') || (*tmp == '\\')) {
                    tmp++;
                    break;
                }
		tmp--;
            }
	    if (pos == len) tmp++;
	    
            processName = [[NSString allocWithZone:environmentZone]
                                     initWithCString:tmp];
        }
#else        
        processName = AUTORELEASE([[NSString allocWithZone:environmentZone]
                                             initWithCString:argv[0]]);
        processName = RETAIN([processName lastPathComponent]);
#endif

        /* Copy the argument list */
        {
            id *argstr;

            argstr = Malloc (argc * sizeof(id));
            for (i = 0; i < argc; i++) {
                argstr[i]
                    = AUTORELEASE([[NSString allocWithZone:environmentZone]
                                      initWithCString:argv[i]]);
            }
            arguments = [[NSArray allocWithZone:environmentZone]
                            initWithObjects:argstr count:argc];
            lfFree(argstr);
        }
    
        /* Count the the evironment variables. */
        for (count = 0; env[count]; count++)
            /* nothing */ ;

#if 1
        /* Copy the environment variables. */
        {
            id *keys, *vals;
	
            keys = Malloc (count * sizeof(id));
            vals = Malloc (count * sizeof(id));
            for (i = 0; i < count; i++) {
                char     *cp, *p;
                unsigned keyLen, valLen;

#if defined(__MINGW32__)
                {
                    unsigned char *buf = objc_atomic_malloc(2048);
                    DWORD         len;

                    len = ExpandEnvironmentStrings(env[i], buf, 2046);
                    if (len > 2046) {
                        buf = objc_realloc(buf, len + 2);
                        len = ExpandEnvironmentStrings(env[i], buf, len);
                    }
                    
                    if (len == 0) {
                        p = Strdup (env[i]);
                        objc_free (buf); buf = NULL;
                    }
                    else {
                        p = buf;
                        buf = NULL;
                    }
                }
#else                
                p = Strdup (env[i]);
#endif
                for (cp = p; *cp != '=' && *cp; cp++);
                *cp = '\0';
                
                keyLen = strlen(p);
                cp++;
                valLen = strlen(cp);
                
                vals[i] = [[NSString allocWithZone:environmentZone]
                                     initWithCString:cp length:valLen];
                keys[i] = [[NSString allocWithZone:environmentZone]
                                     initWithCString:p length:keyLen];
                lfFree(p);
            }
            environment = [[NSDictionary allocWithZone:environmentZone]
                              initWithObjects:vals forKeys:keys count:count];
            lfFree(keys);
            lfFree(vals);
        }
#else
        environment = [[NSDictionary alloc] init];
#endif

        gethostname(str, 1024);
        hostName = [[NSString allocWithZone:environmentZone]
                       initWithCString:str];

        RELEASE(pool);
    }
}

+ (NSString*)operatingSystem
{
    return operatingSystem;
}

+ (NSProcessInfo*)processInfo
{
    if (processInfo == nil) {
	fprintf (stderr, "You must call +[NSProcessInfo "
			 "initializeWithArguments:count:environment:] "
			 "in main()\n");
	exit (1);
    }
    return processInfo;
}

- (id)init
{
    return self;
}

- (NSArray*)arguments
{
    return arguments;
}

- (NSDictionary*)environment
{
    return environment;
}

- (NSString*)hostName
{
    return hostName;
}

- (int)processIdentifier
{
#if defined(__MINGW32__)
    return (int)GetCurrentProcessId();
#else                     
    return (int)getpid();
#endif
}

- (NSString*)processName
{
    return processName;
}

- (NSString*)globallyUniqueString
{
    static int counter = 0;
    static NSRecursiveLock* lock = nil;

    if (!lock)
        lock = [NSRecursiveLock new];

    [lock lock];
    counter++;
    [lock unlock];
    
    return [NSString stringWithFormat:@"%s:%d:%p:%f:%d",
                     [hostName cString],
                     [self processIdentifier],
                     [NSThread currentThread],
                     [[NSDate date] timeIntervalSince1970],
                     counter];
}

- (void)setProcessName:(NSString*)aName
{
    if (aName && [aName length])
        ASSIGN(processName, aName);
}

/*
 * internal class that cannot be deleted
 */

- (id)autorelease
{
    return self;
}

- (void)release
{
    return;
}

- (id)retain
{
    return self;
}

@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

