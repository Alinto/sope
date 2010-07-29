/* 
   NSTask.m

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

#include <Foundation/common.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#if defined(__WIN32__)
#  ifdef __CYGWIN32__
#    warning using win task on Cygwin32
#  endif
#  include "NSConcreteWindowsTask.h"
#  define NSConcreteTask NSConcreteWindowsTask
#else
#  ifdef __CYGWIN32__
#    warning using unix task on Cygwin32
#  endif
#  include "NSConcreteUnixTask.h"
#  define NSConcreteTask NSConcreteUnixTask
#endif

NSString *NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

@implementation NSTask

+ (id)allocWithZone:(NSZone*)zone
{
    NSTask *task = (NSTask *)
	NSAllocateObject((self == [NSTask class])
			 ? [NSConcreteTask class] : (Class)self,
			 0, zone);
    return task;
}

+ (NSTask *)launchedTaskWithLaunchPath:(NSString*)path
  arguments:(NSArray*)arguments
{
    id aTask;
    
    aTask = [[NSConcreteTask alloc] init];
    [aTask setLaunchPath:path];
    [aTask setArguments:arguments];
    [aTask setEnvironment:[[NSProcessInfo processInfo] environment]];
    [aTask launch];

    return AUTORELEASE(aTask);
}

- (void)setLaunchPath:(NSString *)path
{
    [self shouldNotImplement:_cmd];
}

- (void)setArguments:(NSArray*)arguments
{
    [self shouldNotImplement:_cmd];
}

- (void)setEnvironment:(NSDictionary*)dict
{
    [self shouldNotImplement:_cmd];
}

- (void)setCurrentDirectoryPath:(NSString*)path
{
    [self shouldNotImplement:_cmd];
}

- (void)setStandardInput:(id)input
{
    [self shouldNotImplement:_cmd];
}

- (void)setStandardOutput:(id)output
{
    [self shouldNotImplement:_cmd];
}

- (void)setStandardError:(id)error
{
    [self shouldNotImplement:_cmd];
}

- (NSString*)launchPath
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (NSArray*)arguments
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (NSDictionary*)environment
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (NSString*)currentDirectoryPath
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)standardInput
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)standardOutput
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (id)standardError
{
    [self shouldNotImplement:_cmd];
    return nil;
}

- (void)launch
{
    [self shouldNotImplement:_cmd];
}

- (void)terminate
{
    [self shouldNotImplement:_cmd];
}

- (void)interrupt
{
    [self shouldNotImplement:_cmd];
}

- (BOOL)isRunning
{
    [self shouldNotImplement:_cmd];
    return NO;
}

- (int)terminationStatus
{
    [self shouldNotImplement:_cmd];
    return 0;
}

- (void)waitUntilExit
{
    [self shouldNotImplement:_cmd];
}

- (unsigned int)processId
{
    [self shouldNotImplement:_cmd];
    return 0;
}

@end /* NSTask */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
