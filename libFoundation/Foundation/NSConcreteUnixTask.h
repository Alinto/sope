/* 
   NSConcreteUnixTask.h

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

#include <Foundation/NSTask.h>

@interface NSConcreteUnixTask : NSTask
{
@private
    pid_t        pid;
    NSString     *taskPath;
    NSString     *currentDirectory;
    NSArray      *taskArguments;
    NSDictionary *taskEnvironment;
    int          status;
    id           standardInput;  // either NSPipe or NSFileHandle
    id           standardOutput; // either NSPipe or NSFileHandle
    id           standardError;  // either NSPipe or NSFileHandle
    BOOL         isRunning;
    BOOL         childHasFinished;
}
@end
