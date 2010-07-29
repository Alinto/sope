/* 
   NSConcreteWindowsTask.h
   
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

#ifndef __NSConcreteWindowsTask_H__
#define __NSConcreteWindowsTask_H__

#include <Foundation/NSTask.h>

#include <config.h>

#if defined(HAVE_WINDOWS_H)
#  include <windows.h>

@interface NSConcreteWindowsTask : NSTask
{
  PROCESS_INFORMATION pi;
  NSString     *taskPath;
  NSString     *currentDirectory;
  NSArray      *taskArguments;
  NSDictionary *taskEnvironment;
  id           standardInput;  // either NSPipe or NSFileHandle
  id           standardOutput; // either NSPipe or NSFileHandle
  id           standardError;  // either NSPipe or NSFileHandle
}

@end

#endif /* HAVE_WINDOWS_H */

#endif /* __NSConcreteWindowsTask_H__ */
