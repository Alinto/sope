/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __WebDAV_SoObject_SoDAV_H__
#define __WebDAV_SoObject_SoDAV_H__

#import <Foundation/NSObject.h>

/*
  SoObject DAV Protocol
  
  This informal protocol contains methods that can be implemented by
  SoObject's supporting WebDAV authoring. For most methods a default
  implementation is provided.
*/

@class NSString, NSDate, NSEnumerator, NSException, NSDictionary, NSArray;
@class EOFetchSpecification, EOGlobalID, EODataSource;
@class SoDAVLockManager;

@interface NSObject(SoObjectSoDAV)

/*
  This method is invoked on SoObjects if a WebDAV PROPFIND or SEARCH
  request was issued.
*/
- (id)performWebDAVQuery:(EOFetchSpecification *)_fs inContext:(id)_ctx;
- (id)performWebDAVBulkQuery:(EOFetchSpecification *)_fs inContext:(id)_ctx;
- (NSEnumerator *)davChildKeysInContext:(id)_ctx;
- (EODataSource *)contentDataSourceInContext:(id)_ctx;
- (NSArray *)davQueryOnSelf:(EOFetchSpecification *)_fs inContext:(id)_ctx;

- (NSArray *)defaultWebDAVPropertyNamesInContext:(id)_ctx;
- (NSArray *)davComplianceClassesInContext:(id)_ctx;
- (NSArray *)davAllowedMethodsInContext:(id)_ctx;

/*
  Editing the object properties (PROPPATCH)
*/
- (NSException *)davSetProperties:(NSDictionary *)_setProps
  removePropertiesNamed:(NSArray *)_delProps
  inContext:(id)_ctx;
- (id)davCreateObject:(NSString *)_name
  properties:(NSDictionary *)_props
  inContext:(id)_ctx;
- (NSException *)davCreateCollection:(NSString *)_name inContext:(id)_ctx;
- (NSException *)davCreateCalendarCollection:(NSString *)_name inContext:(id)_ctx;

- (NSException *)davMoveToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx;
- (NSException *)davCopyToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx;

/*
  Use the attribute map to map WebDAV propery names to KVC keys for the
  object. If the object returns a map, the SoObjectWebDAVDispatcher will
  properly justify the EOFetchSpecification for queries.
*/
- (id)davAttributeMapInContext:(id)_ctx;
+ (id)defaultWebDAVAttributeMap;

/*
  WebDAV supports locking/unlocking of resources, you can override the
  default locking mechanism used by implementing this method.
*/
- (SoDAVLockManager *)davLockManagerInContext:(id)_ctx;


/* some DAV properties are mapped to some keys by default */

- (BOOL)davIsCollection;  // tries -isCollection and NSFileType, otherwise NO
- (BOOL)davIsFolder;      // same as -davIsCollection
- (BOOL)davHasSubFolders; // same as -davIsFolder
- (BOOL)davIsHidden;      // returns NO
- (BOOL)davIsExecutable;  // returns NO

- (id)davUid;             // tries -globalID, otherwise same as -davURL
- (id)davEntityTag;
- (id)davURL;             // tries -baseURLInContext:, -baseURL otherwise nil
- (id)davContentLength;   // tries NSFileSize, -contentLength, otherwise 0
- (NSString *)davContentType;

- (NSDate *)davLastModified; // tries NSFileModificationDate, otherwise now
// tries NSFileCreationDate, NSFileModificationDate, otherwise nil
- (NSDate *)davCreationDate;

// tries -displayName, NSFileSubject,NSFileName,NSFilePath, -path otherwise nil
- (NSString *)davDisplayName;
- (NSString *)davResourceType; // uses -davIsCollection

// uses -davIsCollection (urn:content-class:folder or urn:content-class:item)
- (NSString *)davContentClass;


- (BOOL)davDenySubFolders;
- (unsigned int)davChildCount;
- (unsigned int)davObjectCount;
- (unsigned int)davVisibleCount;

@end

#endif /* __WebDAV_SoObject_SoDAV_H__ */
