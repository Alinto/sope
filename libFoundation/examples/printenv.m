/*
   printenv.m

   Copyright (C) 1999 Helge Hess.
   All rights reserved.

   Author: Helge Hess <hh@mdlink.de>
   Date: March 1999

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

#include <Foundation/Foundation.h>

/*
  This tool prints to stdout the environment variables as decoded by
  NSProcessInfo.
*/

int main (int argc, char** argv, char** env)
{
#if LIB_FOUNDATION_LIBRARY
    [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

    {
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      NSDictionary      *env  = [[NSProcessInfo processInfo] environment];
      NSEnumerator      *names;
      NSString          *name;

      names = [[[env allKeys]
                     sortedArrayUsingSelector:@selector(compare:)]
                     objectEnumerator];
      while ((name = [names nextObject])) {
        NSString *value = [env objectForKey:name];

        printf("%s=%s\n", [name cString], [value cString]);
      }
      RELEASE(pool);
    }
    exit (0);
    return 0;
}
