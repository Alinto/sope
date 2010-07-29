/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __NGExtensions_NGResourceLocator_H__
#define __NGExtensions_NGResourceLocator_H__

#import <Foundation/NSObject.h>

/*
  NGResourceLocator
  
  This class can be used by libraries to lookup resources in either the GNUstep
  hierarchy or in FHS locations (/usr/local etc).
  
  The pathes given in are relative to the respective root, eg: "Library/Models"
  and "share/mytool/models".
*/

@class NSString, NSArray, NSFileManager, NSMutableDictionary;

@interface NGResourceLocator : NSObject
{
  NSString      *gsSubPath;
  NSString      *fhsSubPath;
  NSFileManager *fileManager;
  
  NSArray             *searchPathes;
  NSMutableDictionary *nameToPathCache;
  
  struct {
    int cacheSearchPathes:1;
    int cachePathHits:1;
    int cachePathMisses:1;
    int reserved:29;
  } flags;
}
/* The 'GNUstepPath' is a string describing the required path.  This
 * is the relative location of the path in a standard GNUstep
 * hierarchy when a standard GNUstep hierarchy is being used; but if
 * gnustep-base (which supports arbitrary filesystem layouts) is being
 * used, the path is heuristically mapped to the standard paths
 * accepted by NSSearchPathForDirectoriesInDomains using the following
 * logic:
 *
 *  "Library/WebApplications" --> GSWebApplicationsDirectory
 *  "Library/Libraries"       --> GSLibrariesDirectory
 *  "Tools"                   --> GSToolsDirectory
 *  "Tools/Admin"             --> GSAdminToolsDirectory
 *  "Applications"            --> GSApplicationsDirectory
 *  "Applications/Admin"      --> GSAdminApplicationsDirectory
 *  "Library/xxx"             --> NSLibraryDirectory/xxx
 *  "yyy"                     --> NSLibraryDirectory/yyy
 *  
 * In the last two cases 'xxx' and 'yyy' are arbitrary strings/paths
 * that don't match anything else.  Eg, if you create an
 * NGResourceLocators to look up files in "Library/Resources" you will
 * get one that looks them up in NSLibraryDirectory/Resources (which
 * means a list of directories containing
 * GNUSTEP_USER_LIBRARY/Resources, GNUSTEP_LOCAL_LIBRARY/Resources,
 * GNUSTEP_NETWORK_LIBRARY/Resources,
 * GNUSTEP_SYSTEM_LIBRARY/Resources).
 */
+ (id)resourceLocatorForGNUstepPath:(NSString *)_path fhsPath:(NSString *)_fhs;
- (id)initWithGNUstepPath:(NSString *)_path fhsPath:(NSString *)_fhs;

/* resource pathes */

/* It's not a good idea to access these directly if you want portable
 * code.  More logical to use directly the 'operations' lookup methods
 * below which encapsulate all the internal filesystem details.
 */
- (NSArray *)gsRootPathes;  /* GNUSTEP_PATHPREFIX_LIST or MacOSX */
- (NSArray *)fhsRootPathes;
- (NSArray *)searchPathes;

/* operations */

/* These are public and work across all types of filesystems, it's how you find resources.  */
- (NSString *)lookupFileWithName:(NSString *)_name;
- (NSString *)lookupFileWithName:(NSString *)_name extension:(NSString *)_ext;

- (NSArray *)lookupAllFilesWithExtension:(NSString *)_ext
  doReturnFullPath:(BOOL)_withPath;
/* End public */

@end

#endif /* __NGExtensions_NGResourceLocator_H__ */
