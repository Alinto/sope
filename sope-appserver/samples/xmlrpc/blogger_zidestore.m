/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "NGBloggerClient.h"
#include "common.h"

static void runIt(void) {
  NGBloggerClient *client;
  NSString     *url, *login, *password;
  id result;
  
  // ADJUST!
  login    = @"helge";
  password = @"secret";
  url      = @"http://localhost/zidestore/so/helge";
  
  client = [[NGBloggerClient alloc] initWithURL:url];
  [client setLogin:login];
  [client setPassword:password];
  
  result = [client getUsersBlogs];
  NSLog(@"result: %@", result);
  
  [client release];
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  runIt();
  [pool release];
  return 0;
}
