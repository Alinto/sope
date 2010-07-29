/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGExtensions/NGResourceLocator.h>
#include "common.h"

static void usage(void) {
  fprintf(stderr, 
          "usage: sope-rsrclookup <gnustep-subdir> <fhs-subdir> <rsrc>\n");
}

static void testit(NSArray *args) {
  NGResourceLocator *loc;
  NSString *gs, *fhs, *rsrc;
  
  if ([args count] < 3) {
    usage();
    exit(2);
  }
  
  gs   = [args objectAtIndex:1];
  fhs  = [args objectAtIndex:2];
  loc  = [NGResourceLocator resourceLocatorForGNUstepPath:gs fhsPath:fhs];
  rsrc = [args count] < 4 ? nil : [args objectAtIndex:3];
  
  if (rsrc == nil) {
    NSArray *a;
    
    if ((a = [loc gsRootPathes]) != nil)
      NSLog(@"GNUstep Lookup Pathes: %@", a);

    if ((a = [loc fhsRootPathes]) != nil)
      NSLog(@"FHS Lookup Pathes: %@", a);

    if ((a = [loc searchPathes]) != nil)
      NSLog(@"Pathes: %@", a);
  }
  else {
    NSString *p;
    
    p = [loc lookupFileWithName:rsrc];
    if (p == nil) {
      fprintf(stderr, "did not find resource: %s\n", [rsrc cString]);
      exit(1);
    }
    printf("%s\n", [p cString]);
  }
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  testit([[NSProcessInfo processInfo] argumentsWithoutDefaults]);
  
  [pool release];
  return 0;
}
