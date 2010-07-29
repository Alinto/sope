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

#ifndef __NGXmlRpc_AsyncResultProxy_H__
#define __NGXmlRpc_AsyncResultProxy_H__

#import <Foundation/NSObject.h>

@class NSException, NSMutableArray, NSString, NSMutableArray;

@interface NGAsyncResultProxy : NSObject
{
  BOOL           isReady;
  id             result;
  id             target;
  SEL            action;
  NSString       *token;       /* response token for NGObjWeb */
  NSMutableArray *keptObjects; /* keep RC for those objects   */
}

- (BOOL)isReady;
- (id)result;

- (void)postResult:(id)_result;
- (void)postFaultResult:(NSException *)_result;

- (void)setTarget:(id)_target;
- (id)target;
- (void)setAction:(SEL)_action;
- (SEL)action;

- (void)setToken:(NSString *)_token;
- (NSString *)token;

- (void)becameReady; /* for subclasses to cleanup */

- (void)retainObject:(id)_object;
- (void)releaseObject:(id)_object;

@end

#endif /* __SkyDaemon_AsyncResultProxy_H__ */
