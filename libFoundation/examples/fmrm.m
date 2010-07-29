/*
   fmrm.m

   Copyright (C) 2000 Helge Hess.
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>
   Date:   April 2000

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

/*
  This is an example for using the NSFileManager class to remove
  files in the filesystem.
*/

#include <Foundation/Foundation.h>

int main(int argc, char **argv, char **env) {
  NSArray       *args;
  NSFileManager *fm;
  BOOL          ok;
  int           i;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 2) {
    NSLog(@"usage: %@ <files>", [args objectAtIndex:0]);
    exit(1);
  }

  fm = [NSFileManager defaultManager];

  for (i = 1; i < [args count]; i++) {
    NSString *path = [args objectAtIndex:i];
    
    ok = [fm removeFileAtPath:path handler:nil];
    if (!ok)
      NSLog(@"could not remove: %@", [args objectAtIndex:1]);
  }
  
  exit(0);
  return 0;
}
