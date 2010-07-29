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

#ifndef __SoObjects_SoSecurityManager_H__
#define __SoObjects_SoSecurityManager_H__

#import <Foundation/NSObject.h>

/*
  SoSecurityManager
  
  This is the central object for security management.
  [TODO: more docu]
  
  Note: security info is associated with SoClasses using SoClassSecurityInfo
  objects. Take a look in the SoClassSecurityInfo.h header file for more
  information.
*/

@class NSString, NSArray, NSException;

@protocol SoUserDatabase // TODO: what about that ?
@end

@interface SoSecurityManager : NSObject
{
}

+ (id)sharedSecurityManager;

/* validation */

- (NSException *)validatePermission:(NSString *)_perm
  onObject:(id)_object 
  inContext:(id)_ctx;

- (NSException *)validateObject:(id)_object inContext:(id)_ctx;

- (NSException *)validateName:(NSString *)_key 
  ofObject:(id)_object
  inContext:(id)_ctx;

- (NSException *)validateValue:(id)_value
  forName:(NSString *)_key 
  ofObject:(id)_object
  inContext:(id)_ctx;

@end

#endif /* __SoObjects_SoSecurityManager_H__ */
