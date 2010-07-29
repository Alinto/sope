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

#ifndef __SoOFS_common_H__
#define __SoOFS_common_H__

#import <Foundation/Foundation.h>

#if NeXT_Foundation_LIBRARY || APPLE_FOUNDATION_LIBRARY || \
    COCOA_Foundation_LIBRARY
#define COCOA_Foundation_LIBRARY 1

#  include <NGExtensions/NGObjectMacros.h>
#  include <NGExtensions/NSString+Ext.h>
#endif

#include <NGExtensions/NGExtensions.h>

#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOApplication.h>
#include <NGExtensions/NGFileManager.h>

#include <SoObjects/NSException+HTTP.h>
#include <SoObjects/SoClass.h>
#include <SoObjects/SoClassRegistry.h>
#include <SoObjects/SoClassSecurityInfo.h>
#include <SoObjects/SoDefaultRenderer.h>
#include <SoObjects/SoObject.h>
#include <SoObjects/SoObjectMethodDispatcher.h>
#include <SoObjects/SoObjectRequestHandler.h>
#include <SoObjects/SoPermissions.h>
#include <SoObjects/SoSecurityManager.h>
#include <SoObjects/SoUser.h>
#include <SoObjects/WOContext+SoObjects.h>
#include <SoObjects/NSException+HTTP.h>
#ifdef COMPILE_FOR_GSTEP_MAKE
#  include "WOContext+private.h" // required for page rendering
#else
/* Xcode can't reference the private header, so as a workaround we declare all
   private methods used here */
#  include <NGObjWeb/WOContext.h>
@interface WOContext(UsedPrivates)
- (void)enterComponent:(WOComponent *)_component content:(WOElement *)_content;
- (void)leaveComponent:(WOComponent *)_component;
- (void)setPage:(WOComponent *)_page;
@end
#endif

@interface WOContext(LastException)
- (NSException *)lastException;
@end

#endif /* __SoOFS_common_H__ */
