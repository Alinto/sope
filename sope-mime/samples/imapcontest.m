/*
  Copyright (C) 2005 SKYRIX Software AG

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

#include <NGImap4/NGImap4ConnectionManager.h>
#include <NGImap4/NGImap4Connection.h>
#include "common.h"

static int runIt(NSArray *args) {
  NGImap4ConnectionManager *cm;
  NGImap4Connection *c;
  NSUserDefaults    *ud;
  id url;
  
  ud  = [NSUserDefaults standardUserDefaults];
  url = [ud stringForKey:@"url"];
  url = url ? [NSURL URLWithString:url] : nil;
  if (url == nil) {
    NSLog(@"ERROR: found no proper URL for connection ('url' default)!");
    return 1;
  }

  printf("connect to: '%s'\n", [[url absoluteString] cString]);
  
  cm = [NGImap4ConnectionManager defaultConnectionManager];
  c  = [cm connectionForURL:url password:[ud stringForKey:@"pwd"]];
  
  NSLog(@"con: %@", c);

  NSLog(@"all: %@", [c allFoldersForURL:url]);
  NSLog(@"sub: %@", [c allFoldersForURL:url]);

  return 0;
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int res;
  
  pool = [NSAutoreleasePool new];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  res = runIt([[NSProcessInfo processInfo] argumentsWithoutDefaults]);

  [pool release];
  return res;
}
