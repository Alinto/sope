/*
  Copyright (C) 2004 Helge Hess

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

#include <NGImap4/NGSieveClient.h>
#include "common.h"

static NSURL *getDefaultsURL(void)  {
  NSUserDefaults *ud;
  NSString *pwd, *user, *host;
  NSString *url;

  ud = [NSUserDefaults standardUserDefaults];
  
  if ((url = [ud stringForKey:@"url"]) != nil)
    return [NSURL URLWithString:url];
  
  user = [ud stringForKey:@"user"];
  pwd  = [ud stringForKey:@"password"];
  host = [ud stringForKey:@"host"];
  
  url = [@"http://" stringByAppendingString:user];
  url = [url stringByAppendingString:@":"];
  url = [url stringByAppendingString:pwd];
  url = [url stringByAppendingString:@"@"];
  url = [url stringByAppendingString:host];
  url = [url stringByAppendingString:@":2000/"];
  return [NSURL URLWithString:url];
}

static int test(NSArray *args) {
  NSUserDefaults *ud;
  NGSieveClient  *client;
  NSURL *url;
  id res;

  ud = [NSUserDefaults standardUserDefaults];
  
  url = getDefaultsURL();
  NSLog(@"check URL: %@", url);
  
  client = [[NGSieveClient alloc] initWithURL:url];
  NSLog(@"  client: %@", client);
  
  res = [client login:[url user] password:[url password]];
  if (![[res valueForKey:@"result"] boolValue]) {
    NSLog(@"could not login %@: %@", [url user], client);
    return 1;
  }
  
  NSLog(@"  login %@: %@", [url user], res);
  NSLog(@"  client: %@", client);
  
  res = [client listScripts];
  NSLog(@"  list: %@", res);
  
  res = [client getScript:@"ogo"];
  NSLog(@"  get 'ogo': %@", res);
  
  return 0;
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int res;
  
  pool = [NSAutoreleasePool new];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  res = test([[NSProcessInfo processInfo] argumentsWithoutDefaults]);
  
  [pool release];
  exit(0);
  /* static linking */
  [NGExtensions class];
  return 0;
}
