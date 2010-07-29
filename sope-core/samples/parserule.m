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

#include <NGExtensions/NGRule.h>
#include "common.h"

/*
  eg:

  ./obj/parserule \
     "a > b => a = 1; 10"           \
     "*true* => color = 'green'; 1" \
     "a>'b' => bool=YES; high"
*/

static int runTest(NSArray *args) {
  NSEnumerator *e;
  NSString *arg;
  
  e = [args objectEnumerator];
  [e nextObject];
  
  while ((arg = [e nextObject])) {
    NGRule *rule;
    
    NSLog(@"Parse: '%@' (len=%i)", arg, [arg length]);
    
    if ((rule = [[NGRule alloc] initWithPropertyList:arg]) == nil) {
      NSLog(@"  parsing failed.");
      continue;
    }
    NSLog(@"  Rule:        %@", rule);
    NSLog(@"    Qualifier: %@ (class=%@)", [rule qualifier],
          NSStringFromClass([[rule qualifier] class]));
    NSLog(@"    Action:    %@ (class=%@)", [rule action],
          NSStringFromClass([[rule action] class]));
    NSLog(@"    Priority:  %i", [rule priority]);
    [rule release];
  }
  return 0;
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int res;
  
  pool = [NSAutoreleasePool new];
  
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  res = runTest([[NSProcessInfo processInfo] argumentsWithoutDefaults]);
  
  [pool release];
  exit(0);
  /* static linking */
  [NGExtensions class];
  return 0;
}
