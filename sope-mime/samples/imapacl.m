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

#include <NGImap4/NGImap4Client.h>
#include <NGImap4/NGImap4FileManager.h>
#include <NGImap4/NGImap4Context.h>
#include "ImapQuotaTool.h"
#include "common.h"

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  ImapQuotaTool *tool;
  int res = 0;
  
  pool = [NSAutoreleasePool new];
  
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  tool = [[ImapQuotaTool alloc] init];

  {
    NGImap4Client *client;
    NSString *mailbox;
    
    client = [[[tool fileManager] imapContext] client];
    
    mailbox = [[NSUserDefaults standardUserDefaults] objectForKey:@"path"];
    NSLog(@"acl test on path: %@", mailbox);
    NSLog(@"  acl %@", [[client getACL:mailbox] valueForKey:@"acl"]);
    
    NSLog(@"  set urks 'lr' %@", 
	  [[client setACL:mailbox rights:@"lr" uid:@"urks"] 
	    valueForKey:@"result"]);
    NSLog(@"  acl %@", [[client getACL:mailbox] valueForKey:@"acl"]);
    
    NSLog(@"  rm urks %@", 
	  [[client deleteACL:mailbox uid:@"urks"] valueForKey:@"result"]);
    NSLog(@"  acl %@", [[client getACL:mailbox] valueForKey:@"acl"]);
    
    
    NSLog(@"  my rights: '%@'",
	  [[client myRights:mailbox] valueForKey:@"myrights"]);
    
    NSLog(@"  list rights: %@",
	  [[[client listRights:mailbox uid:@"urks"] 
	     valueForKey:@"listrights"] componentsJoinedByString:@","]);
  }  
  [tool release];
  
  [pool release];
  exit(res);
  /* static linking */
  [NGExtensions class];
  return res;
}
