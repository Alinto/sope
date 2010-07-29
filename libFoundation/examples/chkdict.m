/*
   chkdict.m

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
  This is an example for loading a dictionary property list.
*/

#include <Foundation/Foundation.h>

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSArray *args;
  int     i;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 2) {
    NSLog(@"usage: %@ <files>", [args objectAtIndex:0]);
    exit(1);
  }

  for (i = 1; i < [args count]; i++) {
    NSString     *path;
    NSDictionary *plist;
    
    path  = [args objectAtIndex:i];
    plist = [[NSDictionary alloc] initWithContentsOfFile:path];
    if (plist)
      printf("%s: valid (%i entries)\n", [path cString], [plist count]);
    else
      printf("%s: invalid\n", [path cString]);
    
    RELEASE(plist);
  }
  [pool release];
  exit(0);
  return 0;
}
