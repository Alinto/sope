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

+ (id)resourceLocatorForGNUstepPath:(NSString *)_path fhsPath:(NSString *)_fhs;
- (id)initWithGNUstepPath:(NSString *)_path fhsPath:(NSString *)_fhs;

/* resource pathes */

- (NSArray *)gsRootPathes;  /* GNUSTEP_PATHPREFIX_LIST or MacOSX */
- (NSArray *)fhsRootPathes;
- (NSArray *)searchPathes;

/* operations */

- (NSString *)lookupFileWithName:(NSString *)_name;
- (NSString *)lookupFileWithName:(NSString *)_name extension:(NSString *)_ext;

- (NSArray *)lookupAllFilesWithExtension:(NSString *)_ext
  doReturnFullPath:(BOOL)_withPath;

@end

#endif /* __NGExtensions_NGResourceLocator_H__ */
