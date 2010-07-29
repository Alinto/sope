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

#include <NGImap4/NGImap4.h>
#include "common.h"

static void usage(void) {
  fprintf(stderr, "usage: imap_tool"
	  " -login <login>"
	  " -pwd <pwd>"
	  " [-host <host>]\n"
	  " (-action0 select|thread|list|fetch [-arg0 <arg>])*"
	  "\n"
	  "  select arg: <string>\n"
	  "  thread arg: <bool> (threadBySubject?)\n"
	  "  list   arg: <string>\n"
	  "  fetch  arg: <from>:<to>(:<parts>)+\n"
	  );
  exit(1);
}

static BOOL runAction(NGImap4Client *client, NSString *action, NSString *arg) {
  id result;
  
  if ([action length] == 0)
    return NO;
  
  if ([action isEqualToString:@"select"]) {
    result = [client select:arg];
  }
  else if ([action isEqualToString:@"thread"]) {
    result = [client threadBySubject:[arg boolValue] charset:nil];
  }
  else if ([action isEqualToString:@"list"]) {
    result = [client list:arg pattern:@"*"];
  }
  else if ([action isEqualToString:@"fetch"]) {
    NSArray *args;
    NSArray *parts;
    int from, to;
    
    args  = [arg componentsSeparatedByString:@":"];
    parts = [args subarrayWithRange:NSMakeRange(2,[args count] - 2)];
    from  = [[args objectAtIndex:0] intValue];
    to    = [[args objectAtIndex:1] intValue];
    
    result = [client fetchFrom:from to:to parts:parts];
  }
  
  NSLog(@"action: %@:%@ : %@", action, arg, result);
  return YES;
}

static void run(void) {
  NSString       *login, *pwd, *host;
  NSUserDefaults *ud;
  NGImap4Client  *client;
  NSDictionary   *res;
  int            cnt;
  
  ud = [NSUserDefaults standardUserDefaults];

  if ((login = [ud stringForKey:@"login"]) == nil)
    usage();
  if ((pwd = [ud stringForKey:@"pwd"]) == nil)
    usage();
  if ((host = [ud stringForKey:@"host"]) == nil)
    host = @"localhost";
  
  client = [NGImap4Client clientWithHost:host];
  NSLog(@"got client: %@", client);
  
  NSLog(@"attempt login '%@' ...", login);
  res = [client login:login password:pwd];
  if (![[res valueForKey:@"result"] boolValue]) {
    NSLog(@"  login failed: %@", res);
    exit(2);
  }
  
  for (cnt = 0; YES; cnt++) {
    NSString *action;
    NSString *arg;
    
    action = [ud stringForKey:[NSString stringWithFormat:@"action%d", cnt]]; 
    arg    = [ud stringForKey:[NSString stringWithFormat:@"arg%d",    cnt]];
    if (!runAction(client, action, arg))
      break;
  }
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];
  run();
  [pool release];
  return 0;
}

