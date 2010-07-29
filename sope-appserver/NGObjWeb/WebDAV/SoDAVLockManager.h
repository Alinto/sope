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

#ifndef __SoObjects_SoDAVLockManager_H__
#define __SoObjects_SoDAVLockManager_H__

#import <Foundation/NSObject.h>

/*
  A simple implementation of a WebDAV lock manager. Note that this only
  works for single-process servers ... :-( Need some more powerful locking
  class in practice, but for simple stuff which doesn't really need locking
  this is sufficient.
*/

@class NSMutableDictionary;

@interface SoDAVLockManager : NSObject
{
  NSMutableDictionary *uriToLockInfo;
}

+ (id)sharedLockManager;

- (id)lockURI:(NSString *)_uri timeout:(NSString *)_to 
  scope:(NSString *)_scope type:(NSString *)_lockType
  owner:(NSString *)_ownerURL;
- (void)unlockURI:(NSString *)_uri token:(id)_token;

- (id)lockTokenForURI:(NSString *)_uri;

@end

#endif /* __SoObjects_SoDAVLockManager_H__ */
