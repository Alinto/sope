/* 
   NSConcreteWindowsTask.m
   
   Copyright (C) 1999 Helge Hess and MDlink online service center GmbH
   All rights reserved.
   
   Author: Helge Hess <helge.hess@mdlink.de>
   
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

#include "NSConcreteWindowsTask.h"
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSPathUtilities.h>

#if defined(HAVE_WINDOWS_H)
#  include <windows.h>

@implementation NSConcreteWindowsTask

- (id)init
{
  ZeroMemory(&self->pi, sizeof(self->pi));
  return self;
}

- (void)gcFinalize
{
  if (self->pi.hProcess != NULL)
    CloseHandle(self->pi.hProcess);
  if (self->pi.hThread != NULL)
    CloseHandle(self->pi.hThread);
}
- (void)dealloc
{
  [self gcFinalize];
  RELEASE(self->taskPath);
  RELEASE(self->currentDirectory);
  RELEASE(self->taskArguments);
  RELEASE(self->taskEnvironment);
  RELEASE(self->standardInput);
  RELEASE(self->standardOutput);
  RELEASE(self->standardError);
  [super dealloc];
}

/* plain accessors (should catch exceptions) */

- (void)setLaunchPath:(NSString *)path
{
    ASSIGN(self->taskPath, path);
}
- (NSString *)launchPath
{
    return self->taskPath;
}

- (void)setArguments:(NSArray *)arguments
{
    ASSIGN(self->taskArguments, arguments);
}
- (NSArray *)arguments
{
    return self->taskArguments;
}

- (void)setEnvironment:(NSDictionary *)dict
{
    ASSIGN(self->taskEnvironment, dict);
}
- (NSDictionary *)environment
{
    return self->taskEnvironment;
}

- (void)setCurrentDirectoryPath:(NSString *)path
{
    ASSIGN(self->currentDirectory, path);
}
- (NSString *)currentDirectoryPath
{
    return self->currentDirectory;
}

- (void)setStandardInput:(id)input
{
    ASSIGN(self->standardInput, input);
}
- (id)standardInput
{
    return self->standardInput;
}

- (void)setStandardOutput:(id)output
{
    ASSIGN(self->standardOutput, output);
}
- (id)standardOutput
{
    return self->standardOutput;
}

- (void)setStandardError:(id)error
{
    ASSIGN(self->standardError, error);
}
- (id)standardError
{
    return self->standardError;
}

/* Win32 specific info */

- (HANDLE)processHandle
{
  return self->pi.hProcess;
}
- (HANDLE)threadHandle
{
  return self->pi.hThread;
}

/* implementation */

- (void)terminate
{
  BOOL ok;

  ok = TerminateProcess([self processHandle], 10);
}
- (int)terminationStatus
{
  DWORD exitCode;
  BOOL  ok;
  
  ok = GetExitCodeProcess([self processHandle], &exitCode);
  if (ok)
    return exitCode;
  else {
    NSLog(@"Couldn't get exit code of process !");
    return -1;
  }
}

- (void)waitUntilExit
{
  DWORD result;
  
  switch (result = WaitForSingleObject([self processHandle], INFINITE)) {
  case WAIT_ABANDONED:
  case WAIT_OBJECT_0:
  case WAIT_TIMEOUT:
    break;
  }
}
- (unsigned int)processId
{
  return (unsigned int)self->pi.dwProcessId;
}

- (void)launch
{
  BOOL ok;
  STARTUPINFO startUpInfo;
  NSMutableString *cmdline;
  NSEnumerator    *e;
  NSString        *tmp;
  char            *ccmdline;

  cmdline = [[self launchPath] mutableCopy];
  e = [[self arguments] objectEnumerator];
  while ((tmp = [e nextObject])) {
    [cmdline appendString:@" "];
    [cmdline appendString:tmp]; /* should quote tmp first ! */
  }
  ccmdline = objc_malloc([cmdline cStringLength] + 1);
  [cmdline getCString:ccmdline];
  RELEASE(cmdline); cmdline = NULL;

  ZeroMemory(&startUpInfo, sizeof(startUpInfo));
  startUpInfo.cb = sizeof(startUpInfo);
  startUpInfo.dwFlags |= STARTF_USESTDHANDLES;
  startUpInfo.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);
  startUpInfo.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  startUpInfo.hStdError  = GetStdHandle(STD_ERROR_HANDLE);
  
  ok = CreateProcess([[self launchPath] cString], ccmdline,
		     NULL      /* proc attrs */,
		     NULL      /* thread attrs */,
		     1         /* inherit handles */,
		     0         /* creation flags */,
		     NULL      /* env block */,
		     [[self currentDirectoryPath] cString],
		     &startUpInfo,
		     &(self->pi));
  objc_free(ccmdline);
  if (!ok) {
    NSLog(@"Couldn't launch task: %@ !", [self launchPath]);
    return;
  }
}

@end /* NSConcreteWindowsTask */

#endif /* HAVE_WINDOWS_H */
