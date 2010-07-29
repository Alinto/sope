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

#ifndef __OFS_OFSBaseObject_H__
#define __OFS_OFSBaseObject_H__

#import <Foundation/NSObject.h>
#include <NGExtensions/NGFileManager.h>

/*
  OFSBaseObject
  
  This is the base class for OFS objects. Every OFS object has at least
  - a name
  - a container (not retained !)
  - a filemanager
  - a storage path (relative to the filemanager)
  
  Note that filemanager and storage path should in no case be made available
  to the web for security reasons !
  
  The name is tracked in the child since it is required of URL construction
  (to know the URI name the child was found with).
*/

@class NSString, NSException, NSClassDescription;
@class EOGlobalID;
@class WOContext;
@class SoClass;
@class OFSFactoryContext;

@interface OFSBaseObject : NSObject
{
  id<NSObject,NGFileManager> fileManager;
  NSString *storagePath;
  SoClass  *soClass;
  NSString *name;
  id       container;
}

/* accessors */

- (id<NSObject,NGFileManager>)fileManager;
- (NSString *)storagePath;
- (EOGlobalID *)globalID;

- (BOOL)isCollection;
- (BOOL)hasChildren;
- (BOOL)doesExist;

/* containment */

- (id)container;
- (NSString *)nameInContainer;
- (void)setContainer:(id)_container andName:(NSString *)_name;
- (NSException *)takeStorageInfoFromContext:(OFSFactoryContext *)_ctx;

/* operations */

- (void)detachFromContainer;
- (BOOL)isAttachedToContainer;

- (id)DELETEAction:(id)_ctx;

/* instantiation */

- (id)awakeFromFetchInContext:(OFSFactoryContext *)_ctx;
- (id)awakeFromInsertionInContext:(OFSFactoryContext *)_ctx;

/* WebDAV */

- (NSString *)davDisplayName; // returns NSFileSubject or -name

/* key validations */

- (NSException *)validateForDelete;
- (NSException *)validateForInsert;
- (NSException *)validateForUpdate;
- (NSException *)validateForSave;

/* security */

- (NSString *)ownerInContext:(id)_ctx;
- (id)authenticatorInContext:(id)_ctx;

/* version control */

- (BOOL)isCvsControlled;
- (BOOL)isSvnControlled;

@end

#endif /* __OFS_OFSBaseObject_H__ */
