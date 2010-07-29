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

#ifndef __OFS_OFSFolder_H__
#define __OFS_OFSFolder_H__

#include <SoOFS/OFSBaseObject.h>

/*
  OFSFolder
  
  OFSFolder's map to filesystem directories and are "collections" of other
  OFS objects. OFSFolder's can also store custom properties in a special file
  (.props.plist).
  
  How collections are loaded
  ==========================
  When an OFSFolder is loaded, it doesn't instantiate any of it child objects
  (since this would result in a cascade sucking in all the filesystem below.
  As long as OFSFolder isn't sent -allObjects, it isn't fully loaded, instead
  the objects are stored in the children hash and loaded on demand when the key
  is looked up.
  
  How child objects are instantiated
  ==================================
  An OFSFolder also acts as a factory for it's children since it needs to
  unarchive them into memory. That is, it's the task of the folder to select
  an appropriate class for the in-memory representation of a childresource.
  
  Security
  ========
  The folder can manage the owner of the children and manages it's own
  owner. The own owner is stored in the SoOwner field of the propertylist
  and the children in the SoChildOwners field (which has to be a dictionary).
*/

@class NSArray, NSDictionary, NSMutableDictionary, NSString, NSEnumerator;
@class WOResourceManager;
@class SoClass;
@class OFSFactoryContext, OFSFactoryRegistry;

@interface OFSFolder : OFSBaseObject
{
@private
  NSArray             *childNames;
  NSMutableDictionary *children;
  NSDictionary        *props;
  struct {
    BOOL didLoadAll:1;
    BOOL hasCVS:1;
    BOOL hasSvn:1;
    BOOL checkedVersionSpecials:1;
    int  reserved:28;
  } flags;
  WOResourceManager *resourceManager;
}

/* mimic a dictionary */

- (NSArray *)allKeys;
- (NSArray *)allValues;
- (BOOL)hasKey:(NSString *)_key;
- (id)objectForKey:(NSString *)_key;
- (NSEnumerator *)keyEnumerator;
- (NSEnumerator *)objectEnumerator;

- (BOOL)isValidKey:(NSString *)_key;

/* storage */

- (void)willChange;

- (NSString *)storagePathForChildKey:(NSString *)_name;

- (id)restorationFactoryForContext:(OFSFactoryContext *)_ctx;
- (id)creationFactoryForContext:(OFSFactoryContext *)_ctx;

- (NSException *)reload;

/* actions */

- (NSString *)defaultMethodNameInContext:(id)_ctx;

- (id)GETAction:(id)_ctx;
- (id)PUTAction:(id)_ctx;
- (id)MKCOLAction:(id)_ctx;
- (id)DELETEAction:(id)_ctx;

/* security */

- (NSString *)ownerInContext:(id)_ctx;
- (NSString *)ownerOfChild:(id)_child inContext:(id)_ctx;

/* WO integration */

- (WOResourceManager *)resourceManagerInContext:(id)_ctx;

/* factory lookup */

- (OFSFactoryRegistry *)factoryRegistry;
- (id)restorationFactoryForContext:(OFSFactoryContext *)_ctx;
- (id)creationFactoryForContext:(OFSFactoryContext *)_ctx;

@end

#endif /* __OFS_OFSFolder_H__ */
