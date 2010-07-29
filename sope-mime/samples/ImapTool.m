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

#include "ImapTool.h"
#include <NGImap4/NGImap4FileManager.h>
#include "common.h"

@implementation ImapTool

- (void)flush {
  [self->fileManager release]; self->fileManager = nil;
}

- (NGImap4FileManager *)fileManager {
  NSUserDefaults *ud;
  NSString       *pwd, *user, *host;
  id             url;
  
  if (self->fileManager)
    return self->fileManager;
  
  ud = [NSUserDefaults standardUserDefaults];
  
  if ((url = [ud stringForKey:@"url"]))
    url = [NSURL URLWithString:url];
  
  if ((user = [ud stringForKey:@"user"]) == nil)
    user = [url user];
  if ((pwd = [ud stringForKey:@"password"]) == nil)
    pwd = [url password];
  if ((host = [ud stringForKey:@"host"]) == nil)
    host = [(NSURL *)url host];
  
  self->fileManager = [[NGImap4FileManager alloc] initWithUser:user
						  password:pwd
						  host:host];
  if (self->fileManager == nil) {
    if (user == nil) NSLog(@"missing login.");
    if (pwd  == nil) NSLog(@"missing password.");
    if (host == nil) NSLog(@"missing host.");
  }
  
  return self->fileManager;
}

@end /* ImapTool */ 
