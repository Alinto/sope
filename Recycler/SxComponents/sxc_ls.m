/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "common.h"
#include <SxComponents/SxComponentRegistry.h>

@interface SxcLsTool : NSObject
- (int) runWithArguments: (NSArray*) _args;
@end

@implementation SxcLsTool

- (void)list:(NSArray *)result indent:(int)indent {
  NSEnumerator *e;
  NSString *c;
  
  if (result == nil) {
    fprintf(stderr, "got no result from registry !\n");
    exit(2);
    return;
  }

  if ([result isKindOfClass:[NSException class]]) {
    NSLog(@"got excetpion: %@", result);
    return;
  }
  else if ([result isKindOfClass:[NSDictionary class]]) {
    NSLog(@"got dictionary: %@", result);
    return;
  }
  
  result = [result sortedArrayUsingSelector:@selector(compare:)];
  
  e = [result objectEnumerator];
  while ((c = [e nextObject])) {
    int i;
    for (i = 0; i < indent; i++)
      printf("  ");
      
    printf("%s\n", [c cString]);
  }
}

- (int)runWithArguments:(NSArray *)_args {
  SxComponentRegistry *reg;

  reg = [SxComponentRegistry defaultComponentRegistry];
  
  if ([_args count] == 1) {
    [self list:[reg listComponents] indent:0];
  }
  else {
    NSEnumerator *e;
    NSString *prefix;
    
    e = [_args objectEnumerator];
    [e nextObject]; // cmd name
    while ((prefix = [e nextObject])) {
      printf("[%s]\n", [prefix cString]);
      [self list:[reg listComponents:prefix] indent:1];
    }
  }
  return 0;
}

@end

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSArray           *args;
  int       exitCode;
  SxcLsTool *tool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] argumentsWithoutDefaults];

  tool = [[SxcLsTool alloc] init];
  exitCode = [tool runWithArguments:args];
  RELEASE(tool);
  
  RELEASE(pool);
  exit(exitCode);
  return exitCode;
}
