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

#include "SoDAVLockManager.h"
#include "common.h"

@interface SoDAVLockInfo : NSObject
{
@public
  NSString       *token;
  NSCalendarDate *expireDate;
}

- (id)initWithToken:(NSString *)_token;
- (BOOL)isValid;

@end

@implementation SoDAVLockManager

+ (id)sharedLockManager {
  static SoDAVLockManager *lm = nil; // THREAD
  if (lm == nil) lm = [[self alloc] init];
  return lm;
}

- (id)init {
  if ((self = [super init])) {
    self->uriToLockInfo = [[NSMutableDictionary alloc] initWithCapacity:64];
  }
  return self;
}
- (void)dealloc {
  [self->uriToLockInfo release];
  [super dealloc];
}

- (id)lockURI:(NSString *)_uri timeout:(NSString *)_to 
  scope:(NSString *)_scope type:(NSString *)_lockType
  owner:(NSString *)_ownerURL
{
  /* returns the lock token */
  SoDAVLockInfo *lockInfo;
  
  if ((lockInfo = [self->uriToLockInfo objectForKey:_uri])) {
    if (![lockInfo isValid]) {
      /* remove invalid lock */
      [self->uriToLockInfo removeObjectForKey:_uri];
      lockInfo = nil;
    }
  }
  
  if (lockInfo != nil)
    /* already locked */
    return nil;
  
  lockInfo = [[SoDAVLockInfo alloc] initWithToken:
    [@"opaquelocktoken:" stringByAppendingString:
	[[NSProcessInfo processInfo] globallyUniqueString]]];
  [self->uriToLockInfo setObject:lockInfo forKey:_uri];
  [lockInfo autorelease];
  return lockInfo->token;
}

- (void)unlockURI:(NSString *)_uri token:(id)_token {
  [self->uriToLockInfo removeObjectForKey:_uri];
}

- (id)lockTokenForURI:(NSString *)_uri {
  SoDAVLockInfo *lockInfo;
  
  if ((lockInfo = [self->uriToLockInfo objectForKey:_uri])) {
    if (![lockInfo isValid]) {
      /* remove invalid lock */
      [self->uriToLockInfo removeObjectForKey:_uri];
      lockInfo = nil;
    }
  }
  return [lockInfo isNotNull] ? lockInfo->token : (NSString *)nil;
}

@end /* SoDAVLockManager */

@implementation SoDAVLockInfo

- (id)initWithToken:(NSString *)_token {
  if ((self = [super init])) {
    self->token = [_token copy];
  }
  return self;
}

- (void)dealloc {
  [self->token      release];
  [self->expireDate release];
  [super dealloc];
}

- (BOOL)isValid {
  return YES;
}

@end /* SoDAVLockInfo */
