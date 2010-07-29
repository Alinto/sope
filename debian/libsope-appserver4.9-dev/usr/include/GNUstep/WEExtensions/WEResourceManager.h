/*
  Copyright (C) 2005 SKYRIX Software AG

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

#ifndef __WEExtensions_WEResourceManager_H__
#define __WEExtensions_WEResourceManager_H__

#include <NGObjWeb/WOResourceManager.h>

/*
  WEResourceManager

  This class extends the WOResourceManager with the capability to separate
  templates (whether .wox or .html) from the resources of a bundle.

  Instead of placing the templates inside the bundle, they will live in either
    $GNUSTEP_xxx_ROOT/Library/$APPNAME/Templates/$BUNDLE/$TEMPLATE
  or in
    /usr/XX/share/$APPNAME/templates/$BUNDLE/$TEMPLATE
*/

@class NSArray, NSMutableDictionary;
@class WEStringTableManager, WEResourceKey;

@interface WEResourceManager : WOResourceManager
{
@private
  NSMutableDictionary  *keyToComponentPath;
  NSMutableDictionary  *keyToURL;
  NSMutableDictionary  *keyToPath;
  WEStringTableManager *labelManager;
  WEResourceKey        *cachedKey;
}

+ (NSArray *)rootPathesInGNUstep; /* GNUSTEP_PATHLIST */
+ (NSArray *)rootPathesInFHS;     /* /usr/local, /usr */
+ (NSArray *)availableThemes;

@end


#include <NGObjWeb/WOApplication.h>

@interface WOApplication(WEResourceManager)

- (NSString *)shareDirectoryName;
- (NSString *)gsTemplatesDirectoryName;
- (NSString *)gsWebDirectoryName;

@end

#endif /* __WEExtensions_WEResourceManager_H__ */
