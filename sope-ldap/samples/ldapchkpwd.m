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

#import <EOControl/EOControl.h>
#import <NGLdap/NGLdapConnection.h>
#include "common.h"

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSUserDefaults *ud;
  NSArray        *args;
  BOOL ok = NO;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 3) {
    NSLog(@"usage: %@ <user> <password>", [args objectAtIndex:0]);
    exit(1);
  }
  
  ud = [NSUserDefaults standardUserDefaults];
  
  ok = [NGLdapConnection checkPassword:[args objectAtIndex:2]
                         ofLogin:[args objectAtIndex:1]
                         atBaseDN:[ud stringForKey:@"LDAPRootDN"]
                         onHost:[ud stringForKey:@"LDAPHost"]
                         port:[ud integerForKey:@"LDAPPort"]];
  if (ok)
    printf("authenticated successfully.\n");
  else
    printf("did not authenticate !\n");
  
  [pool release];
  
  exit(0);
  return 0;
}
