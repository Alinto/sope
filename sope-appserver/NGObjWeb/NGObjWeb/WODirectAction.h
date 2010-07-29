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

#ifndef __NGObjWeb_WODirectAction_H__
#define __NGObjWeb_WODirectAction_H__

#import <Foundation/NSObject.h>
#include <NGObjWeb/WOActionResults.h>

@class NSString, NSDictionary, NSArray;
@class WORequest, WOComponent, WOSession, WOContext;

@interface WODirectAction : NSObject
{
  WOContext *context;
}

- (id)initWithContext:(WOContext *)_context;
- (id)initWithRequest:(WORequest *)_request;

/* accessors */

- (WORequest *)request;
- (id)session;
- (id)existingSession;

/* actions */

- (id<WOActionResults>)performActionNamed:(NSString *)_actionName;

- (void)takeFormValuesForKeyArray:(NSArray *)_keys;
- (void)takeFormValuesForKeys:(NSString *)_key1,...;
- (void)takeFormValueArraysForKeyArray:(NSArray *)_keys;
- (void)takeFormValueArraysForKeys:(NSString *)_key1,...;

/* pages */

- (id)pageWithName:(NSString *)_name;

@end

@interface WODirectAction(NGObjWebAdditions)

- (WOContext *)context;

@end

@interface WODirectAction(WODebugging)
/* implemented in NGExtensions */

- (void)debugWithFormat:(NSString *)_format, ...;
- (void)logWithFormat:(NSString *)_format, ...;

@end

#endif /* __NGObjWeb_WODirectAction_H__ */
